import XCTest
@testable import MindSync

final class AudioAnalysisErrorTests: XCTestCase {
    
    // MARK: - Error Description Tests
    
    func testFileNotFoundError_HasCorrectDescription() {
        // Given
        let error = AudioAnalysisError.fileNotFound
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Audio file not found")
    }
    
    func testDRMProtectedError_HasCorrectDescription() {
        // Given
        let error = AudioAnalysisError.drmProtected
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "DRM-protected file cannot be analyzed")
    }
    
    func testUnsupportedFormatError_HasCorrectDescription() {
        // Given
        let error = AudioAnalysisError.unsupportedFormat
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Audio format is not supported")
    }
    
    func testCancelledError_HasCorrectDescription() {
        // Given
        let error = AudioAnalysisError.cancelled
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Analysis cancelled")
    }
    
    func testFileTooLongError_HasCorrectDescriptionWithDuration() {
        // Given: 45 minute file
        let duration: Double = 45 * 60 // 2700 seconds
        let error = AudioAnalysisError.fileTooLong(duration: duration)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("45 minutes"), "Error should mention 45 minutes")
        XCTAssertTrue(description!.contains("too long"), "Error should mention file is too long")
        XCTAssertTrue(description!.contains("30 minutes"), "Error should mention 30 minute limit")
    }
    
    func testFileTooLongError_WithDifferentDuration_FormatsCorrectly() {
        // Given: 60 minute file
        let duration: Double = 60 * 60 // 3600 seconds
        let error = AudioAnalysisError.fileTooLong(duration: duration)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("60 minutes"), "Error should mention 60 minutes")
    }
    
    func testAnalysisFailureError_IncludesUnderlyingError() {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 123, 
                                     userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = AudioAnalysisError.analysisFailure(underlying: underlyingError)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("Analysis failed"), "Should mention analysis failed")
        XCTAssertTrue(description!.contains("Test error"), "Should include underlying error description")
    }
}
