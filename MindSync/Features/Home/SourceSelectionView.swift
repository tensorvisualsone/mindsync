import SwiftUI
import MediaPlayer

/// View for audio source selection
struct SourceSelectionView: View {
    private let mediaLibraryService = ServiceContainer.shared.mediaLibraryService
    @State private var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @State private var showingMediaPicker = false
    @State private var selectedItem: MPMediaItem?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onSongSelected: (MPMediaItem) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("Select Audio Source")
                    .font(.title.bold())
                
                // Local music library
                Button(action: {
                    requestMediaLibraryAccess()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                        Text("Music Library")
                            .font(.headline)
                        Text("Choose a song from your local music library")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .disabled(authorizationStatus == .denied)
                
                // Microphone mode (for later)
                Button(action: {
                    // TODO: Implement microphone mode (Phase 8)
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 50))
                        Text("Microphone")
                            .font(.headline)
                        Text("Analyze music from external sources")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .disabled(true)  // Not yet implemented
                
                if authorizationStatus == .denied {
                    Text("Access to music library denied. Please enable in Settings.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Audio Source")
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
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                authorizationStatus = mediaLibraryService.authorizationStatus
            }
        }
    }
    
    private func requestMediaLibraryAccess() {
        Task {
            let status = await mediaLibraryService.requestAuthorization()
            await MainActor.run {
                authorizationStatus = status
                if status == .authorized {
                    showingMediaPicker = true
                } else if status == .denied {
                    errorMessage = "Access to music library was denied. Please enable in Settings."
                    showingError = true
                }
            }
        }
    }
    
    private func handleItemSelection(_ item: MPMediaItem) {
        // Check if song can be analyzed
        if mediaLibraryService.canAnalyze(item: item) {
            selectedItem = item
            onSongSelected(item)
            showingMediaPicker = false
        } else {
            errorMessage = "This song is DRM-protected and cannot be analyzed. Please choose another song or use microphone mode."
            showingError = true
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
        picker.showsCloudItems = false  // Only local files
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
        
        init(onItemSelected: @escaping (MPMediaItem) -> Void, onCancel: @escaping () -> Void) {
            self.onItemSelected = onItemSelected
            self.onCancel = onCancel
        }
        
        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            if let item = mediaItemCollection.items.first {
                onItemSelected(item)
            }
            mediaPicker.dismiss(animated: true)
        }
        
        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            onCancel()
            mediaPicker.dismiss(animated: true)
        }
    }
}

#Preview {
    SourceSelectionView { item in
        print("Selected: \(item.title ?? "Unknown")")
    }
}

