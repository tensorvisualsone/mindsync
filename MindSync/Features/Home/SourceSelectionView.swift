import SwiftUI
import MediaPlayer
import UniformTypeIdentifiers
import AVFoundation

/// View for audio source selection
struct SourceSelectionView: View {
    @State private var mediaLibraryService: MediaLibraryService?
    @State private var permissionsService: PermissionsService?
    @State private var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @State private var showingMediaPicker = false
    @State private var showingFilePicker = false
    @State private var selectedItem: MPMediaItem?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onSongSelected: (MPMediaItem) -> Void
    let onFileSelected: (URL) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppConstants.Spacing.xl) {
                    // Header
                    VStack(spacing: AppConstants.Spacing.sm) {
                        Text(NSLocalizedString("sourceSelection.title", comment: ""))
                            .font(AppConstants.Typography.title)
                            .accessibilityIdentifier("sourceSelection.title")
                        
                        Text(NSLocalizedString("sourceSelection.subtitle", comment: "Subtitle for source selection"))
                            .font(AppConstants.Typography.subheadline)
                            .foregroundColor(.mindSyncSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppConstants.Spacing.md)
                    }
                    .padding(.top, AppConstants.Spacing.lg)
                    
                    // Source Selection Cards
                    VStack(spacing: AppConstants.Spacing.md) {
                        // File Picker Card (Recommended)
                        SourceCard(
                            icon: "folder.fill",
                            iconColor: .mindSyncSuccess,
                            title: NSLocalizedString("sourceSelection.filePicker.title", comment: ""),
                            description: NSLocalizedString("sourceSelection.filePicker.description", comment: ""),
                            badge: NSLocalizedString("sourceSelection.filePicker.advantage", comment: ""),
                            badgeColor: .mindSyncSuccess,
                            isRecommended: true,
                            action: {
                                HapticFeedback.light()
                                showingFilePicker = true
                            }
                        )
                        .accessibilityIdentifier("sourceSelection.filePickerButton")
                        
                        // Music Library Card
                        SourceCard(
                            icon: "music.note.list",
                            iconColor: .mindSyncInfo,
                            title: NSLocalizedString("sourceSelection.musicLibrary", comment: ""),
                            description: NSLocalizedString("sourceSelection.musicLibraryDescription", comment: ""),
                            badge: NSLocalizedString("sourceSelection.musicLibrary.drmWarning", comment: ""),
                            badgeColor: .mindSyncWarning,
                            isRecommended: false,
                            isDisabled: authorizationStatus == .denied,
                            action: {
                                HapticFeedback.light()
                                requestMediaLibraryAccess()
                            }
                        )
                        .accessibilityIdentifier("sourceSelection.musicLibraryButton")
                        .accessibilityLabel(NSLocalizedString("sourceSelection.musicLibraryButton", comment: ""))
                        .accessibilityHint(NSLocalizedString("sourceSelection.musicLibraryHint", comment: ""))
                        
                        if authorizationStatus == .denied {
                            HStack(spacing: AppConstants.Spacing.sm) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.mindSyncError)
                                    .font(.system(size: AppConstants.IconSize.small))
                                Text(NSLocalizedString("sourceSelection.musicLibraryDenied", comment: "Message shown when music library access is denied"))
                                    .font(AppConstants.Typography.caption)
                                    .foregroundColor(.mindSyncError)
                            }
                            .padding(AppConstants.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .mindSyncCardStyle()
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                }
                .padding(.bottom, AppConstants.Spacing.lg)
            }
            .navigationTitle(NSLocalizedString("sourceSelection.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingMediaPicker) {
                MediaPickerView(
                    onItemSelected: { item in
                        handleItemSelection(item)
                    },
                    onCancel: {
                        showingMediaPicker = false
                    }
                )
            }
            .alert(NSLocalizedString("common.error", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("common.ok", comment: ""), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.audio]) { result in
                handleFileImport(result)
            }
            .task {
                // Initialize services on Main Actor to avoid crashes
                let services = ServiceContainer.shared
                mediaLibraryService = services.mediaLibraryService
                permissionsService = services.permissionsService
                authorizationStatus = services.mediaLibraryService.authorizationStatus
            }
        }
        .mindSyncBackground()
    }
    
    private func requestMediaLibraryAccess() {
        guard let mediaLibraryService = mediaLibraryService else { return }
        Task {
            let status = await mediaLibraryService.requestAuthorization()
            await MainActor.run {
                authorizationStatus = status
                if status == .authorized {
                    showingMediaPicker = true
                } else if status == .denied {
                    errorMessage = NSLocalizedString("error.musicLibraryDenied", comment: "")
                    showingError = true
                }
            }
        }
    }
    
    private func handleItemSelection(_ item: MPMediaItem) {
        // Check if song can be analyzed
        guard let mediaLibraryService = mediaLibraryService else { return }
        
        Task {
            do {
                _ = try await mediaLibraryService.assetURLForAnalysis(of: item)
                await MainActor.run {
                    // Only call onSongSelected if validation succeeds
                    selectedItem = item
                    onSongSelected(item)
                    showingMediaPicker = false
                }
            } catch {
                await MainActor.run {
                    // MediaLibraryValidationError implements LocalizedError with proper localization
                    // Use errorDescription directly for MediaLibraryValidationError to ensure proper formatting
                    if let mediaError = error as? MediaLibraryValidationError,
                       let description = mediaError.errorDescription {
                        errorMessage = description
                    } else {
                        // Fallback for other error types
                        errorMessage = error.localizedDescription
                    }
                    // Keep media picker open so user can select another song
                    // Don't call onSongSelected - this ensures selectedMediaItem in HomeView stays nil
                    showingError = true
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("File picker returned URL: \(url.path)")
            
            Task {
                // Start accessing the security-scoped resource
                let hasAccess = url.startAccessingSecurityScopedResource()
                print("Security scoped access: \(hasAccess)")
                
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                // Copy file to app's documents directory for persistent access
                guard let copiedURL = copyAudioToDocuments(from: url) else {
                    print("ERROR: Failed to copy file to documents")
                    await MainActor.run {
                        errorMessage = NSLocalizedString("error.file.copyFailed", comment: "")
                        showingError = true
                    }
                    return
                }
                
                print("File copied successfully to: \(copiedURL.path)")
                
                // Validate that the file is playable
                let asset = AVURLAsset(url: copiedURL)
                do {
                    let isPlayable = try await asset.load(.isPlayable)
                    
                    if isPlayable {
                        // Call callback on main actor - this triggers navigation
                        await MainActor.run {
                            print("File import successful, calling onFileSelected with: \(copiedURL.lastPathComponent)")
                            onFileSelected(copiedURL)
                        }
                    } else {
                        try? FileManager.default.removeItem(at: copiedURL)
                        await MainActor.run {
                            errorMessage = NSLocalizedString("error.file.invalidAudio", comment: "")
                            showingError = true
                        }
                    }
                } catch {
                    try? FileManager.default.removeItem(at: copiedURL)
                    await MainActor.run {
                        errorMessage = String(format: NSLocalizedString("error.file.validationFailed", comment: ""), error.localizedDescription)
                        showingError = true
                    }
                }
            }
            
        case .failure(let error):
            errorMessage = String(format: NSLocalizedString("error.file.selectionFailed", comment: ""), error.localizedDescription)
            showingError = true
        }
    }
    
    /// Copies the audio file to the app's documents directory
    private func copyAudioToDocuments(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Create Music subdirectory if needed
        let musicDir = documentsURL.appendingPathComponent("Music", isDirectory: true)
        try? fileManager.createDirectory(at: musicDir, withIntermediateDirectories: true)
        
        // Generate unique filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mp3" : sourceURL.pathExtension
        let fileName = "\(originalName)_\(timestamp).\(fileExtension)"
        let destinationURL = musicDir.appendingPathComponent(fileName)
        
        // Copy file using Data for security-scoped resource compatibility
        do {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL)
            return destinationURL
        } catch {
            // Fallback: try FileManager copy
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                return destinationURL
            } catch {
                print("Error copying audio file: \(error.localizedDescription)")
                return nil
            }
        }
    }
}

/// Wrapper for MPMediaPickerController
struct MediaPickerView: UIViewControllerRepresentable {
    let onItemSelected: (MPMediaItem) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = true  // Show cloud items as well (Apple Music)
        return picker
    }
    
    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onItemSelected: onItemSelected, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onItemSelected: (MPMediaItem) -> Void
        let onCancel: () -> Void
        private var hasHandledSelection = false
        
        init(onItemSelected: @escaping (MPMediaItem) -> Void, onCancel: @escaping () -> Void) {
            self.onItemSelected = onItemSelected
            self.onCancel = onCancel
        }
        
        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            // Prevent multiple calls
            guard !hasHandledSelection else { return }
            hasHandledSelection = true
            
            guard let item = mediaItemCollection.items.first else {
                // No item selected - just cancel
                DispatchQueue.main.async { [weak self] in
                    self?.onCancel()
                }
                return
            }
            
            // Ensure UI updates happen on main thread
            // Note: Don't call dismiss here - SwiftUI sheet will handle it
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onItemSelected(item)
            }
        }
        
        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            // Prevent multiple calls
            guard !hasHandledSelection else { return }
            hasHandledSelection = true
            
            // Ensure UI updates happen on main thread
            // Note: Don't call dismiss here - SwiftUI sheet will handle it
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onCancel()
            }
        }
    }
}

// MARK: - Source Card Component

private struct SourceCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String?
    let badgeColor: Color?
    let isRecommended: Bool
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppConstants.Spacing.md) {
                HStack(alignment: .top) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    
                    Spacer()
                    
                    // Recommended Badge
                    if isRecommended {
                        Text(NSLocalizedString("sourceSelection.recommended", comment: "Recommended badge"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, AppConstants.Spacing.sm)
                            .padding(.vertical, AppConstants.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(iconColor)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                    Text(title)
                        .font(AppConstants.Typography.headline)
                        .foregroundColor(.mindSyncPrimaryText)
                    
                    Text(description)
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(.mindSyncSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let badge = badge, let badgeColor = badgeColor {
                        HStack(spacing: AppConstants.Spacing.xs) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(badgeColor)
                            Text(badge)
                                .font(AppConstants.Typography.caption2)
                                .foregroundColor(badgeColor)
                        }
                        .padding(.top, AppConstants.Spacing.xs)
                    }
                }
            }
            .padding(AppConstants.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mindSyncCardStyle()
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    SourceSelectionView(
        onSongSelected: { item in
            print("Selected: \(item.title ?? "Unknown")")
        },
        onFileSelected: { url in
            print("File selected: \(url.lastPathComponent)")
        }
    )
}


