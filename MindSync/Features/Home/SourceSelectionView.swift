import SwiftUI
import MediaPlayer
import UniformTypeIdentifiers
import AVFoundation

/// View for audio source selection
struct SourceSelectionView: View {
    @State private var mediaLibraryService: MediaLibraryService?
    @State private var permissionsService: PermissionsService?
    @State private var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @State private var microphoneStatus: MicrophonePermissionStatus = .undetermined
    @State private var showingMediaPicker = false
    @State private var showingFilePicker = false
    @State private var selectedItem: MPMediaItem?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onSongSelected: (MPMediaItem) -> Void
    let onFileSelected: ((URL) -> Void)?
    let onMicrophoneSelected: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppConstants.Spacing.sectionSpacing) {
                Text(NSLocalizedString("sourceSelection.title", comment: ""))
                    .font(AppConstants.Typography.title)
                    .accessibilityIdentifier("sourceSelection.title")
                
                // Direct file selection (RECOMMENDED)
                Button(action: {
                    HapticFeedback.light()
                    showingFilePicker = true
                }) {
                    VStack(spacing: AppConstants.Spacing.md) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: AppConstants.IconSize.extraLarge))
                            .foregroundColor(.mindSyncSuccess)
                        Text("Datei auswählen")
                            .font(AppConstants.Typography.headline)
                        Text("MP3/M4A aus Dateien wählen (empfohlen)")
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(.mindSyncSecondaryText)
                            .multilineTextAlignment(.center)
                        
                        Text("✓ Funktioniert mit allen lokalen Audiodateien")
                            .font(AppConstants.Typography.caption2)
                            .foregroundColor(.mindSyncSuccess)
                            .multilineTextAlignment(.center)
                            .padding(.top, AppConstants.Spacing.xs)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppConstants.Spacing.md)
                    .mindSyncCardStyle()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sourceSelection.filePickerButton")
                
                // Local music library
                Button(action: {
                    HapticFeedback.light()
                    requestMediaLibraryAccess()
                }) {
                    VStack(spacing: AppConstants.Spacing.md) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: AppConstants.IconSize.extraLarge))
                            .foregroundColor(.mindSyncInfo)
                        Text(NSLocalizedString("sourceSelection.musicLibrary", comment: ""))
                            .font(AppConstants.Typography.headline)
                        Text(NSLocalizedString("sourceSelection.musicLibraryDescription", comment: ""))
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(.mindSyncSecondaryText)
                            .multilineTextAlignment(.center)
                        
                        // Warning about DRM
                        Text("⚠️ Apple Music Songs sind DRM-geschützt")
                            .font(AppConstants.Typography.caption2)
                            .foregroundColor(.mindSyncWarning)
                            .multilineTextAlignment(.center)
                            .padding(.top, AppConstants.Spacing.xs)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppConstants.Spacing.md)
                    .mindSyncCardStyle()
                }
                .buttonStyle(.plain)
                .disabled(authorizationStatus == .denied)
                .accessibilityIdentifier("sourceSelection.musicLibraryButton")
                .accessibilityLabel(NSLocalizedString("sourceSelection.musicLibraryButton", comment: ""))
                .accessibilityHint(NSLocalizedString("sourceSelection.musicLibraryHint", comment: ""))
                
                // Microphone mode
                Button(action: {
                    HapticFeedback.light()
                    requestMicrophoneAccess()
                }) {
                    VStack(spacing: AppConstants.Spacing.md) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: AppConstants.IconSize.extraLarge))
                            .foregroundColor(.mindSyncInfo)
                        Text(NSLocalizedString("sourceSelection.microphone", comment: ""))
                            .font(AppConstants.Typography.headline)
                        Text(NSLocalizedString("sourceSelection.microphoneDescription", comment: ""))
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(.mindSyncSecondaryText)
                            .multilineTextAlignment(.center)
                        
                        // Info about latency
                        Text(NSLocalizedString("sourceSelection.microphoneNote", comment: ""))
                            .font(AppConstants.Typography.caption2)
                            .foregroundColor(.mindSyncWarning)
                            .multilineTextAlignment(.center)
                            .padding(.top, AppConstants.Spacing.xs)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppConstants.Spacing.md)
                    .mindSyncCardStyle()
                }
                .buttonStyle(.plain)
                .disabled(microphoneStatus == .denied || onMicrophoneSelected == nil)
                .accessibilityIdentifier("sourceSelection.microphoneButton")
                .accessibilityLabel(NSLocalizedString("sourceSelection.microphoneButton", comment: ""))
                .accessibilityHint(NSLocalizedString("sourceSelection.microphoneHint", comment: ""))
                
                if authorizationStatus == .denied {
                    Text(NSLocalizedString("sourceSelection.musicLibraryDenied", comment: "Message shown when music library access is denied"))
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(.mindSyncError)
                        .multilineTextAlignment(.center)
                        .padding(AppConstants.Spacing.md)
                }
                
                if microphoneStatus == .denied {
                    Text(NSLocalizedString("sourceSelection.microphoneDenied", comment: "Message shown when microphone access is denied"))
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(.mindSyncError)
                        .multilineTextAlignment(.center)
                        .padding(AppConstants.Spacing.md)
                }
            }
            .padding(AppConstants.Spacing.md)
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
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff]) { result in
                handleFileImport(result)
            }
            .task {
                // Initialize services on Main Actor to avoid crashes
                let services = ServiceContainer.shared
                mediaLibraryService = services.mediaLibraryService
                permissionsService = services.permissionsService
                authorizationStatus = services.mediaLibraryService.authorizationStatus
                microphoneStatus = services.permissionsService.microphoneStatus
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
    
    private func requestMicrophoneAccess() {
        guard let permissionsService = permissionsService else { return }
        Task {
            let granted = await permissionsService.requestMicrophoneAccess()
            await MainActor.run {
                microphoneStatus = permissionsService.microphoneStatus
                if granted {
                    onMicrophoneSelected?()
                } else {
                    errorMessage = NSLocalizedString("error.microphonePermissionDenied", comment: "")
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
            Task {
                // Start accessing the security-scoped resource
                let hasAccess = url.startAccessingSecurityScopedResource()
                
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                // Copy file to app's documents directory for persistent access
                guard let copiedURL = copyAudioToDocuments(from: url) else {
                    await MainActor.run {
                        errorMessage = "Datei konnte nicht kopiert werden. Bitte versuche es erneut."
                        showingError = true
                    }
                    return
                }
                
                // Validate that the file is playable
                let asset = AVURLAsset(url: copiedURL)
                do {
                    let isPlayable = try await asset.load(.isPlayable)
                    
                    await MainActor.run {
                        if isPlayable {
                            onFileSelected?(copiedURL)
                        } else {
                            try? FileManager.default.removeItem(at: copiedURL)
                            errorMessage = "Die Datei ist keine gültige Audiodatei."
                            showingError = true
                        }
                    }
                } catch {
                    try? FileManager.default.removeItem(at: copiedURL)
                    await MainActor.run {
                        errorMessage = "Fehler beim Prüfen der Audiodatei: \(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
            
        case .failure(let error):
            errorMessage = "Fehler beim Auswählen der Datei: \(error.localizedDescription)"
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

#Preview {
    SourceSelectionView(
        onSongSelected: { item in
            print("Selected: \(item.title ?? "Unknown")")
        },
        onFileSelected: { url in
            print("File selected: \(url.lastPathComponent)")
        },
        onMicrophoneSelected: {
            print("Microphone selected")
        }
    )
}

