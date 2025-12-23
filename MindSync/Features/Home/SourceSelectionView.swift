import SwiftUI
import MediaPlayer

/// View zur Auswahl der Audio-Quelle
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
                Text("Audio-Quelle wählen")
                    .font(.title.bold())
                
                // Lokale Musikbibliothek
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
                
                // Mikrofon-Modus (für später)
                Button(action: {
                    // TODO: Mikrofon-Modus implementieren (Phase 8)
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 50))
                        Text("Mikrofon")
                            .font(.headline)
                        Text("Analysiere Musik von externen Quellen")
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
                .disabled(true)  // Noch nicht implementiert
                
                if authorizationStatus == .denied {
                    Text("Zugriff auf Musikbibliothek verweigert. Bitte in den Einstellungen aktivieren.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Audio-Quelle")
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
    
    private func handleItemSelection(_ item: MPMediaItem) {
        // Prüfe ob Song analysierbar ist
        if mediaLibraryService.canAnalyze(item: item) {
            selectedItem = item
            onSongSelected(item)
            showingMediaPicker = false
        } else {
            errorMessage = "Dieser Song ist DRM-geschützt und kann nicht analysiert werden. Bitte wähle einen anderen Song oder verwende den Mikrofon-Modus."
            showingError = true
        }
    }
}

/// Wrapper für MPMediaPickerController
struct MediaPickerView: UIViewControllerRepresentable {
    let onItemSelected: (MPMediaItem) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = false  // Nur lokale Dateien
        return picker
    }
    
    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {
        // Keine Updates nötig
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

