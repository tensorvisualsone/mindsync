# MindSync Developer Guide

Welcome to the MindSync development documentation. This guide will help you get started with the project and understand the development workflow.

## Prerequisites

- Xcode 15.0+
- iOS 17.0+ SDK
- Swift 5.9+

## Getting Started

1. Clone the repository
2. Open `MindSync.xcodeproj`
3. Select the `MindSync` scheme
4. Choose a simulator or connected device
5. Build and Run (Cmd+R)

## Project Structure

The project follows a standard Feature-based architecture:

- **App**: Entry point and global app state (`MindSyncApp.swift`, `AppState.swift`)
- **Core**: Core business logic and algorithms
  - `Audio`: Audio analysis, beat detection, playback
  - `Entrainment`: Light script generation, frequency mapping
  - `Light`: Flashlight and Screen controllers
  - `Safety`: Thermal management, fall detection
- **Features**: SwiftUI Views and ViewModels grouped by feature
  - `Home`, `Session`, `Settings`, `History`, `Onboarding`
- **Services**: Shared services managed by `ServiceContainer`
- **Models**: Data models (`Session`, `AudioTrack`, `UserPreferences`)
- **Shared**: Reusable components, constants, extensions

## Key Architectural Patterns

### Service Container
We use a singleton `ServiceContainer` for dependency injection. Services are initialized once and accessed via `ServiceContainer.shared`.
View Models should accept services in their initializer to allow for dependency injection in tests.

Example:
```swift
init(historyService: SessionHistoryServiceProtocol = ServiceContainer.shared.sessionHistoryService) { ... }
```

### Audio Analysis Pipeline
The audio analysis happens in `AudioAnalyzer`. It uses `AVAssetReader` to read PCM data and performs FFT-based beat detection.
- Analysis results are **cached** in the Caches directory to improve performance for repeated sessions.
- Large files are handled with memory limits (max 30 mins).

### Light Synchronization
Light synchronization is driven by `CADisplayLink` for high precision (60/120Hz).
- **Flashlight**: Controlled via `AVCaptureDevice`. Subject to thermal throttling.
- **Screen**: Controlled via SwiftUI `Color` updates. Optimized using `ScreenStrobeView` to isolate high-frequency updates from the main View hierarchy.

### Concurrency
- We use Swift Concurrency (`async`/`await`) for asynchronous tasks.
- ViewModels and Services are marked with `@MainActor` to ensure UI safety.
- `SessionState` and other state enums are `Equatable` to help with View updates.

## Testing

We prioritize testing for critical components.

### Unit Tests
Located in `MindSyncTests/Unit`.
Run with Cmd+U.
- Test ViewModels using Mocks (e.g., `MockSessionHistoryService`).
- Test Core algorithms (beat detection logic, frequency mapping).

### Integration Tests
Located in `MindSyncTests/Integration`.
- `AudioAnalyzerIntegrationTests`: Verifies the analysis pipeline.

### UI Tests
Located in `MindSyncUITests`.
- Basic flow verification. Note that some features (Flashlight) cannot be fully tested in Simulator.

## Performance Optimization

- **Audio**: Analysis results are cached.
- **UI**: High-frequency updates (Strobe) are isolated in dedicated subviews (`ScreenStrobeView`) to prevent full view tree re-rendering.
- **Memory**: Large audio files are validated before loading.

## Code Style

- Use `MARK:` comments to organize code sections.
- Document public APIs with Swift Doc comments (`///`).
- Use `NSLocalizedString` for all user-facing text.
- Prefer `struct` for Views and Models.
- Use `final class` for Services and ViewModels.

## Release Process

1. Increment Build Number in Target settings.
2. Verify all tests pass.
3. Check `Info.plist` for required privacy descriptions (Microphone, Media Library).
4. Archive and Distribute.

## Common Issues & Debugging

- **Flashlight not working**: Only works on real device. Check Thermal State.
- **Audio Analysis failed**: Check if file is DRM protected (Apple Music tracks cannot be analyzed).
- **UI Stuttering**: Ensure high-frequency updates are not triggering full view body re-evaluations. Use `ScreenStrobeView` pattern.
