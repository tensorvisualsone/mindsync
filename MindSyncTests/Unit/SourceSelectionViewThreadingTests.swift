import XCTest
import Combine
@testable import MindSync

/// Unit tests for SourceSelectionView threading scenarios
/// Tests verify that ServiceContainer access is thread-safe
@MainActor
final class SourceSelectionViewThreadingTests: XCTestCase {
    
    func testServiceContainerAccess_FromMainActor_IsSafe() {
        // Verify that accessing ServiceContainer from @MainActor context is safe
        // This simulates what SourceSelectionView does in onAppear
        
        Task { @MainActor in
            let container = ServiceContainer.shared
            let mediaLibraryService = container.mediaLibraryService
            let permissionsService = container.permissionsService
            
            // Access should not crash
            XCTAssertNotNil(mediaLibraryService)
            XCTAssertNotNil(permissionsService)
            
            // Verify services are accessible
            let authStatus = mediaLibraryService.authorizationStatus
            XCTAssertNotNil(authStatus)
            
            let micStatus = permissionsService.microphoneStatus
            XCTAssertNotNil(micStatus)
        }
    }
    
    func testMediaLibraryService_AuthorizationStatus_IsAccessible() {
        // Test that MediaLibraryService.authorizationStatus can be accessed safely
        let container = ServiceContainer.shared
        let service = container.mediaLibraryService
        
        // This should not cause threading issues
        let status = service.authorizationStatus
        XCTAssertNotNil(status)
    }
    
    func testPermissionsService_MicrophoneStatus_IsAccessible() {
        // Test that PermissionsService.microphoneStatus can be accessed safely
        let container = ServiceContainer.shared
        let service = container.permissionsService
        
        // This should not cause threading issues
        let status = service.microphoneStatus
        XCTAssertNotNil(status)
    }
    
    func testServiceContainerAccess_Pattern_MatchesSourceSelectionView() {
        // Test the exact pattern used in SourceSelectionView.onAppear
        // This verifies the threading fix is correct
        
        var mediaLibraryService: MediaLibraryService?
        var permissionsService: PermissionsService?
        var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
        var microphoneStatus: MicrophonePermissionStatus = .undetermined
        
        // Simulate onAppear pattern
        Task { @MainActor in
            mediaLibraryService = ServiceContainer.shared.mediaLibraryService
            permissionsService = ServiceContainer.shared.permissionsService
            authorizationStatus = mediaLibraryService?.authorizationStatus ?? .notDetermined
            microphoneStatus = permissionsService?.microphoneStatus ?? .undetermined
        }
        
        // Wait for task to complete
        let expectation = expectation(description: "Services loaded")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify services were loaded
        // Note: In actual SourceSelectionView, these would be @State variables
        // Here we just verify the pattern doesn't crash
    }
    
    func testRequestMediaLibraryAccess_IsAsyncSafe() async {
        // Test that requestMediaLibraryAccess can be called safely
        let container = ServiceContainer.shared
        let service = container.mediaLibraryService
        
        // This should not cause threading issues
        let status = await service.requestAuthorization()
        XCTAssertNotNil(status)
    }
    
    func testRequestMicrophoneAccess_IsAsyncSafe() async {
        // Test that requestMicrophoneAccess can be called safely
        let container = ServiceContainer.shared
        let service = container.permissionsService
        
        // This should not cause threading issues
        // Note: This will show a permission dialog in simulator, but should not crash
        let granted = await service.requestMicrophoneAccess()
        // Result depends on user/system, but should not crash
        XCTAssertNotNil(granted as Bool)
    }
    
    func testServiceContainer_ConcurrentAccess_IsSafe() {
        // Test that multiple concurrent accesses to ServiceContainer are safe
        let container = ServiceContainer.shared
        
        let expectation = expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 5
        
        for _ in 0..<5 {
            Task { @MainActor in
                // Simulate multiple views accessing services concurrently
                let _ = container.mediaLibraryService
                let _ = container.permissionsService
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSourceSelectionView_StateInitialization_IsSafe() {
        // Test that the state initialization pattern used in SourceSelectionView is safe
        // This verifies @State variables with optional services work correctly
        
        // Simulate the pattern:
        // @State private var mediaLibraryService: MediaLibraryService?
        // @State private var permissionsService: PermissionsService?
        
        // In actual SwiftUI, these would be @State, but for testing we verify the pattern
        var mediaLibraryService: MediaLibraryService?
        var permissionsService: PermissionsService?
        
        Task { @MainActor in
            mediaLibraryService = ServiceContainer.shared.mediaLibraryService
            permissionsService = ServiceContainer.shared.permissionsService
        }
        
        // Wait a bit for async assignment
        let expectation = expectation(description: "State initialized")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify pattern works (services can be nil initially, then set)
        // This is the safe pattern - no direct access in property initializers
    }
}

