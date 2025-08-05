//
//  shoulderTests.swift
//  shoulderTests
//
//  Created by Zachary Galbraith on 8/2/25.
//

import Testing
import Foundation
@testable import shoulder

struct shoulderTests {

    @Test func testAppConfiguration() async throws {
        #expect(true, "App configuration tests placeholder")
    }
    
    @Test func testFileSystemPaths() async throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let screenshotPath = homeDir.appendingPathComponent("src/shoulder/screenshots")
        let analysisPath = homeDir.appendingPathComponent("src/shoulder/analyses")
        
        #expect(screenshotPath.path.contains("screenshots"))
        #expect(analysisPath.path.contains("analyses"))
    }
    
    @Test func testDateFormatting() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        #expect(dateString.count == 10)
        #expect(dateString.contains("-"))
    }

}
