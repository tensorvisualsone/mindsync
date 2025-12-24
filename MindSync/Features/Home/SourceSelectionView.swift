import SwiftUI
import MediaPlayer

/// View for audio source selection
struct SourceSelectionView: View {
    private let mediaLibraryService = ServiceContainer.shared.mediaLibraryService
    private let permissionsService = ServiceContainer.shared.permissionsService
    @State private var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @State private var microphoneStatus: MicrophonePermissionStatus = .undetermined
    @State private var showingMediaPicker = false
    @State private var selectedItem: MPMediaItem?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onSongSelected: (MPMediaItem) -> Void
    let onMicrophoneSelected: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("Audioquelle auswählen")
                    .font(.title.bold())
                
                // Local music library
                Button(action: {
                    requestMediaLibraryAccess()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                        Text("Musikbibliothek")
                            .font(.headline)
                        Text("Wähle einen Song aus deiner lokalen Musikbibliothek")
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
                
                // Microphone mode
                Button(action: {
                    requestMicrophoneAccess()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 50))
                        Text("Mikrofon")
                            .font(.headline)
                        Text("Musik aus externen Quellen analysieren")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Info about latency
                        Text(NSLocalizedString("sourceSelection.microphoneNote", comment: ""))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .disabled(microphoneStatus == .denied || onMicrophoneSelected == nil)
                
                if authorizationStatus == .denied {
                    Text(NSLocalizedString("sourceSelection.musicLibraryDenied", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if microphoneStatus == .denied {
                    Text(NSLocalizedString("sourceSelection.microphoneDenied", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
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
            .alert("Fehler", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                authorizationStatus = mediaLibraryService.authorizationStatus
                microphoneStatus = permissionsService.microphoneStatus
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
                    errorMessage = "Zugriff auf Musikbibliothek wurde verweigert. Bitte in den Einstellungen aktivieren."
                    showingError = true
                }
            }
        }
    }
    
    private func requestMicrophoneAccess() {
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
        if mediaLibraryService.canAnalyze(item: item) {
            selectedItem = item
            onSongSelected(item)
            showingMediaPicker = false
        } else {
            errorMessage = "Dieser Titel ist durch DRM geschützt und kann nicht analysiert werden. Bitte wähle einen anderen Titel oder nutze den Mikrofonmodus."
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
    SourceSelectionView(
        onSongSelected: { item in
            print("Selected: \(item.title ?? "Unknown")")
        },
        onMicrophoneSelected: {
            print("Microphone selected")
        }
    )
}

