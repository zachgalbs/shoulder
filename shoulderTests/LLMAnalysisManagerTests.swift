//
//  LLMAnalysisManagerTests.swift
//  shoulderTests
//
//  Created by Zachary Galbraith on 8/4/25.
//

import Testing
import Foundation
@testable import shoulder

@MainActor
struct LLMAnalysisManagerTests {
    
    @Test func testManagerInitialization() async throws {
        let manager = LLMAnalysisManager()
        
        #expect(manager.isServerRunning == false)
        #expect(manager.lastAnalysis == nil)
        #expect(manager.analysisHistory.isEmpty)
        #expect(manager.isAnalyzing == false)
    }
    
    @Test func testAnalysisResultDecoding() async throws {
        let json = """
        {
            "is_valid": true,
            "explanation": "User is focused on coding",
            "detected_activity": "Writing Swift code",
            "confidence": 0.85,
            "timestamp": "2025-01-01T10:30:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AnalysisResult.self, from: data)
        
        #expect(result.is_valid == true)
        #expect(result.explanation == "User is focused on coding")
        #expect(result.detected_activity == "Writing Swift code")
        #expect(result.confidence == 0.85)
        #expect(result.timestamp == "2025-01-01T10:30:00Z")
    }
    
    @Test func testAnalysisRequestEncoding() async throws {
        let context = AnalysisContext(
            app_name: "Xcode",
            window_title: "MyProject",
            user_focus: "Writing code",
            timestamp: Date()
        )
        
        let request = AnalysisRequest(
            text: "Code snippet here",
            context: context
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let decoded = try JSONDecoder().decode(AnalysisRequest.self, from: data)
        
        #expect(decoded.text == "Code snippet here")
        #expect(decoded.context.app_name == "Xcode")
        #expect(decoded.context.window_title == "MyProject")
        #expect(decoded.context.user_focus == "Writing code")
        #expect(decoded.model == "dolphin-mistral:latest")
    }
    
    @Test func testFocusInsightsInitialization() async throws {
        let insights = FocusInsights(
            focusPercentage: 75.0,
            validSessions: 7,
            totalSessions: 10,
            currentFocus: "Writing code",
            recentActivities: ["Coding", "Documentation"]
        )
        
        #expect(insights.focusPercentage == 75.0)
        #expect(insights.validSessions == 7)
        #expect(insights.totalSessions == 10)
        #expect(insights.currentFocus == "Writing code")
        #expect(insights.recentActivities.count == 2)
    }
    
    @Test func testAnalysisDirectoryStructure() async throws {
        // Test that analysis paths follow expected structure
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let analysisBase = homeDir.appendingPathComponent("src/shoulder/analyses")
        
        #expect(analysisBase.path.contains("analyses"))
        #expect(analysisBase.path.contains("shoulder"))
    }
    
    @Test func testErrorHandling() async throws {
        let error = LLMAnalysisError.serverNotRunning
        
        switch error {
        case .serverNotRunning:
            #expect(true)
        default:
            #expect(Bool(false))
        }
    }
    
    @MainActor @Test func testAnalysisHistoryManagement() async throws {
        let manager = LLMAnalysisManager()
        
        let result1 = AnalysisResult(
            is_valid: true,
            explanation: "First analysis",
            detected_activity: "Coding",
            confidence: 0.7,
            timestamp: "2025-01-01T10:00:00Z"
        )
        
        let result2 = AnalysisResult(
            is_valid: false,
            explanation: "Second analysis",
            detected_activity: "Browsing",
            confidence: 0.8,
            timestamp: "2025-01-01T10:05:00Z"
        )
        
        manager.analysisHistory["test1"] = result1
        manager.analysisHistory["test2"] = result2
        
        #expect(manager.analysisHistory.count == 2)
        #expect(manager.analysisHistory["test1"]?.confidence == 0.7)
        #expect(manager.analysisHistory["test2"]?.confidence == 0.8)
    }
}