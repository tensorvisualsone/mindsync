import XCTest
@testable import MindSync

/// Tests for ServiceContainer thread-safety
@MainActor
final class ServiceContainerThreadingTests: XCTestCase {
    
    func testServiceContainerShared_IsAccessibleFromMainActor() {
        // This test verifies that ServiceContainer.shared can be accessed from @MainActor context
        // which is required for thread-safety
        
        let container = ServiceContainer.shared
        
        // Verify all services are accessible
        XCTAssertNotNil(container.audioAnalyzer)
        XCTAssertNotNil(container.audioPlayback)
        XCTAssertNotNil(container.mediaLibraryService)
        XCTAssertNotNil(container.permissionsService)
        XCTAssertNotNil(container.sessionHistoryService)
        XCTAssertNotNil(container.flashlightController)
        XCTAssertNotNil(container.screenController)
        XCTAssertNotNil(container.entrainmentEngine)
        XCTAssertNotNil(container.thermalManager)
        XCTAssertNotNil(container.fallDetector)
        XCTAssertNotNil(container.audioEnergyTracker)
        XCTAssertNotNil(container.affirmationService)
    }
    
    func testServiceContainerShared_IsSingleton() {
        // Verify that ServiceContainer.shared returns the same instance
        let instance1 = ServiceContainer.shared
        let instance2 = ServiceContainer.shared
        
        XCTAssertTrue(instance1 === instance2, "ServiceContainer.shared should return the same instance")
    }
    
    func testMediaLibraryService_IsAccessibleFromMainActor() async {
        // Test that MediaLibraryService can be accessed safely from MainActor context
        let container = ServiceContainer.shared
        let service = container.mediaLibraryService
        
        // Access should not crash
        let status = service.authorizationStatus
        XCTAssertNotNil(status)
    }
    
    func testPermissionsService_IsAccessibleFromMainActor() async {
        // Test that PermissionsService can be accessed safely from MainActor context
        let container = ServiceContainer.shared
        let service = container.permissionsService
        
        // Access should not crash
        let status = service.microphoneStatus
        XCTAssertNotNil(status)
    }
}

