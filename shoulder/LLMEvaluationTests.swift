//
//  LLMEvaluationTests.swift
//  shoulder
//
//  Comprehensive testing and evaluation for LLM analysis
//

import Foundation
import SwiftUI

@MainActor
struct LLMEvaluationTests {
    
    // MARK: - Synthetic Data Generation
    
    struct SyntheticOCRData {
        let category: String
        let appName: String
        let windowTitle: String
        let ocrText: String
        let expectedScore: ClosedRange<Double>
        let expectedKeywords: [String]
    }
    
    static func generateSyntheticData() -> [SyntheticOCRData] {
        var testData: [SyntheticOCRData] = []
        
        // Programming scenarios
        testData.append(contentsOf: [
            SyntheticOCRData(
                category: "Programming",
                appName: "Xcode",
                windowTitle: "ContentView.swift",
                ocrText: """
                struct ContentView: View {
                    @State private var selectedItem: Item?
                    @StateObject private var monitor = ScreenVisibilityMonitor()
                    
                    var body: some View {
                        NavigationSplitView {
                            List(items) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                } label: {
                                    HStack {
                                        Image(systemName: "app.fill")
                                        VStack(alignment: .leading) {
                                            Text(item.appName)
                                                .font(.headline)
                                            Text(item.windowTitle ?? "")
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                """,
                expectedScore: 7.5...9.5,
                expectedKeywords: ["struct", "View", "NavigationSplitView", "State", "function"]
            ),
            SyntheticOCRData(
                category: "Programming",
                appName: "Visual Studio Code",
                windowTitle: "server.py",
                ocrText: """
                @app.post("/analyze")
                async def analyze_screenshot(request: AnalysisRequest):
                    start_time = time.time()
                    
                    try:
                        # Validate input
                        if not request.text or len(request.text.strip()) < 10:
                            raise HTTPException(status_code=400, detail="Insufficient text")
                        
                        # Perform analysis
                        result = await analyze_with_ollama(request.text, request.context)
                        
                        processing_time = (time.time() - start_time) * 1000
                        return AnalysisResult(
                            summary=result["summary"],
                            category=result["category"],
                            productivity_score=result["score"],
                            processing_time_ms=processing_time
                        )
                    except Exception as e:
                        logger.error(f"Analysis failed: {e}")
                        raise HTTPException(status_code=500, detail=str(e))
                """,
                expectedScore: 8.0...9.5,
                expectedKeywords: ["async", "def", "analyze", "request", "HTTPException"]
            ),
            SyntheticOCRData(
                category: "Programming",
                appName: "Terminal",
                windowTitle: "bash",
                ocrText: """
                $ git status
                On branch main
                Your branch is up to date with 'origin/main'.
                
                Changes not staged for commit:
                  modified:   shoulder/LLMAnalysisManager.swift
                  modified:   shoulder/ContentView.swift
                
                $ git add .
                $ git commit -m "Add LLM analysis evaluation framework"
                [main abc123] Add LLM analysis evaluation framework
                 2 files changed, 245 insertions(+), 12 deletions(-)
                """,
                expectedScore: 7.0...8.5,
                expectedKeywords: ["git", "commit", "branch", "modified", "changes"]
            )
        ])
        
        // Communication scenarios
        testData.append(contentsOf: [
            SyntheticOCRData(
                category: "Communication",
                appName: "Slack",
                windowTitle: "#engineering",
                ocrText: """
                John Smith 10:23 AM
                Hey team, just pushed the fix for the login bug. Can someone review PR #234?
                
                Sarah Johnson 10:25 AM
                I'll take a look! 
                
                Mike Chen 10:26 AM
                @john great work on the quick turnaround
                
                You 10:28 AM
                Thanks for the fix John! I'll test it on staging
                
                #engineering | Today at 10:30 AM
                CI/CD Pipeline: Build #567 passed ✅
                """,
                expectedScore: 5.5...7.0,
                expectedKeywords: ["team", "review", "PR", "fix", "message"]
            ),
            SyntheticOCRData(
                category: "Communication",
                appName: "Mail",
                windowTitle: "Inbox - 5 unread",
                ocrText: """
                From: product@company.com
                Subject: Q4 Product Roadmap Review
                
                Hi team,
                
                Please find attached the updated product roadmap for Q4. Key highlights:
                - Launch of AI-powered features
                - Performance improvements
                - Mobile app redesign
                
                Let's discuss in tomorrow's meeting.
                
                Best regards,
                Product Team
                
                Attachments: Q4_Roadmap.pdf (2.3 MB)
                """,
                expectedScore: 6.0...7.5,
                expectedKeywords: ["email", "meeting", "roadmap", "team", "review"]
            )
        ])
        
        // Research scenarios
        testData.append(contentsOf: [
            SyntheticOCRData(
                category: "Research",
                appName: "Safari",
                windowTitle: "SwiftUI Navigation - Apple Developer",
                ocrText: """
                NavigationStack
                
                A view that displays a root view and enables navigation to other views.
                
                Overview
                Use a NavigationStack to present a stack of views. People navigate through the stack by:
                - Selecting a NavigationLink
                - Using programmatic navigation with navigationDestination
                
                Example:
                NavigationStack {
                    List(parks) { park in
                        NavigationLink(park.name, value: park)
                    }
                    .navigationDestination(for: Park.self) { park in
                        ParkDetail(park: park)
                    }
                }
                
                Topics:
                - Creating a Navigation Stack
                - Managing Navigation State
                - Customizing the Navigation Bar
                """,
                expectedScore: 7.0...8.5,
                expectedKeywords: ["NavigationStack", "documentation", "SwiftUI", "example", "API"]
            ),
            SyntheticOCRData(
                category: "Research",
                appName: "Chrome",
                windowTitle: "python async await - Stack Overflow",
                ocrText: """
                Question: How to properly use async/await in Python?
                
                Asked 2 years ago | Modified today | Viewed 234k times
                
                Answer (456 votes):
                
                Python's async/await syntax allows you to write asynchronous code that looks synchronous:
                
                import asyncio
                
                async def fetch_data(url):
                    # Simulate network request
                    await asyncio.sleep(1)
                    return f"Data from {url}"
                
                async def main():
                    results = await asyncio.gather(
                        fetch_data("api.example.com"),
                        fetch_data("api.another.com")
                    )
                    print(results)
                
                asyncio.run(main())
                
                Key points:
                - Use 'async def' to define coroutines
                - Use 'await' to wait for async operations
                - Use asyncio.gather() for concurrent execution
                """,
                expectedScore: 7.5...8.5,
                expectedKeywords: ["async", "await", "Python", "Stack Overflow", "answer"]
            )
        ])
        
        // Documentation scenarios
        testData.append(contentsOf: [
            SyntheticOCRData(
                category: "Documentation",
                appName: "Notion",
                windowTitle: "Technical Specification",
                ocrText: """
                # LLM Analysis System Architecture
                
                ## Overview
                The LLM Analysis System provides real-time productivity insights by analyzing screenshot OCR text.
                
                ## Components
                
                ### 1. Screenshot Capture
                - Captures screen every 60 seconds
                - Uses Core Graphics API
                - Saves to timestamped directories
                
                ### 2. OCR Processing
                - Vision framework for text extraction
                - Async processing pipeline
                - Markdown output format
                
                ### 3. LLM Analysis
                - FastAPI server (Python)
                - Ollama integration
                - Structured JSON responses
                
                ## API Endpoints
                
                | Endpoint | Method | Description |
                |----------|--------|-------------|
                | /health | GET | Server health check |
                | /analyze | POST | Analyze OCR text |
                | /metrics | GET | Prometheus metrics |
                
                ## Performance Requirements
                - Response time < 2 seconds
                - 99% uptime
                - Support 100 concurrent requests
                """,
                expectedScore: 7.0...8.5,
                expectedKeywords: ["architecture", "system", "API", "documentation", "specification"]
            )
        ])
        
        // Media scenarios
        testData.append(contentsOf: [
            SyntheticOCRData(
                category: "Media",
                appName: "YouTube",
                windowTitle: "Swift Tutorial - YouTube",
                ocrText: """
                Now Playing: SwiftUI Tutorial for Beginners
                Channel: Code Academy
                1.2M views • 6 months ago
                
                25:43 / 45:20
                
                Comments (2,345)
                
                Top comment:
                "Best SwiftUI tutorial I've found! The navigation examples at 23:00 are exactly what I needed"
                
                Related videos:
                - Advanced SwiftUI Animations
                - Building Your First iOS App
                - Swift Concurrency Explained
                
                Subscribe | Like | Share | Download
                """,
                expectedScore: 3.0...5.0,
                expectedKeywords: ["video", "YouTube", "tutorial", "watching", "media"]
            )
        ])
        
        // System scenarios
        testData.append(contentsOf: [
            SyntheticOCRData(
                category: "System",
                appName: "Finder",
                windowTitle: "shoulder",
                ocrText: """
                Name                    Date Modified       Size        Kind
                ▼ shoulder             Today, 2:15 PM      --          Folder
                  ▸ .git               Yesterday, 5:30 PM  --          Folder
                  ▸ shoulder.xcodeproj Today, 2:15 PM      --          Folder
                  ▸ shoulder           Today, 2:10 PM      --          Folder
                  ▸ shoulderTests      2 days ago          --          Folder
                    README.md          3 days ago          4 KB        Markdown
                    .gitignore         1 week ago          2 KB        Text
                    Package.swift      Today, 10:00 AM     3 KB        Swift Source
                
                7 items, 245.3 MB available
                """,
                expectedScore: 4.0...6.0,
                expectedKeywords: ["Finder", "folder", "file", "directory", "system"]
            )
        ])
        
        return testData
    }
    
    // MARK: - Test Cases
    
    func testServerHealth() async throws {
        let manager = LLMAnalysisManager()
        
        // Wait for server to start
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Check health
        manager.checkServerHealth()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        assert(manager.isServerRunning == true, "Server should be running")
    }
    
    func testSyntheticDataAnalysis(testData: SyntheticOCRData) async throws {
        let manager = LLMAnalysisManager()
        
        // Ensure server is ready
        if !manager.isServerRunning {
            manager.checkServerHealth()
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        
        // Perform analysis
        let startTime = Date()
        
        let result = try await manager.analyzeScreenshot(
            ocrText: testData.ocrText,
            appName: testData.appName,
            windowTitle: testData.windowTitle
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Validate results
        assert(result.detected_activity.lowercased().contains(testData.category.lowercased()) || 
               testData.category.lowercased().contains(result.detected_activity.lowercased()), 
                "Expected category \(testData.category), got \(result.detected_activity)")
        
        // Use confidence as a proxy for score (0-1 scale, multiply by 10 for 0-10 scale)
        let score = result.confidence * 10
        assert(testData.expectedScore.contains(score),
                "Score \(score) not in expected range \(testData.expectedScore)")
        
        assert(processingTime < 5.0, 
                "Processing took \(processingTime)s, expected < 5s")
        
        // Check for keyword presence in detected activity and explanation
        let combinedText = "\(result.detected_activity) \(result.explanation)".lowercased()
        let foundKeywords = testData.expectedKeywords.filter { keyword in
            combinedText.contains(keyword.lowercased())
        }
        
        let keywordCoverage = Double(foundKeywords.count) / Double(testData.expectedKeywords.count)
        assert(keywordCoverage >= 0.3, 
                "Low keyword coverage: \(keywordCoverage * 100)%")
        
        print("""
        ✅ Analysis completed:
           Activity: \(result.detected_activity) (expected: \(testData.category))
           Confidence: \(result.confidence) (score: \(score), expected: \(testData.expectedScore))
           Valid: \(result.is_valid)
           Time: \(processingTime * 1000)ms
           Keywords: \(foundKeywords.count)/\(testData.expectedKeywords.count) found
        """)
    }
    
    func testBatchPerformance() async throws {
        let manager = LLMAnalysisManager()
        let testData = Self.generateSyntheticData()
        
        // Ensure server is ready
        if !manager.isServerRunning {
            manager.checkServerHealth()
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        
        var results: [(time: TimeInterval, success: Bool)] = []
        
        // Run batch analysis
        for data in testData.prefix(10) {
            let startTime = Date()
            
            do {
                _ = try await manager.analyzeScreenshot(
                    ocrText: data.ocrText,
                    appName: data.appName,
                    windowTitle: data.windowTitle
                )
                
                let elapsed = Date().timeIntervalSince(startTime)
                results.append((elapsed, true))
            } catch {
                let elapsed = Date().timeIntervalSince(startTime)
                results.append((elapsed, false))
                print("Analysis failed: \(error)")
            }
        }
        
        // Calculate metrics
        let successRate = Double(results.filter { $0.success }.count) / Double(results.count)
        let avgTime = results.map { $0.time }.reduce(0, +) / Double(results.count)
        let maxTime = results.map { $0.time }.max() ?? 0
        
        print("""
        
        📊 Batch Analysis Results:
        ===========================
        Total: \(results.count) analyses
        Success Rate: \(String(format: "%.1f%%", successRate * 100))
        Avg Time: \(String(format: "%.2f", avgTime))s
        Max Time: \(String(format: "%.2f", maxTime))s
        """)
        
        assert(successRate >= 0.8, "Success rate should be at least 80%")
        assert(avgTime < 3.0, "Average time should be under 3 seconds")
    }
    
    func testEdgeCases() async throws {
        let manager = LLMAnalysisManager()
        
        // Ensure server is ready
        if !manager.isServerRunning {
            manager.checkServerHealth()
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        
        // Test empty text
        do {
            _ = try await manager.analyzeScreenshot(
                ocrText: "",
                appName: "TestApp",
                windowTitle: nil
            )
            print("ERROR: Should have failed with empty text")
        } catch {
            // Expected
        }
        
        // Test very short text
        do {
            _ = try await manager.analyzeScreenshot(
                ocrText: "Hi",
                appName: "TestApp",
                windowTitle: nil
            )
            print("ERROR: Should have failed with very short text")
        } catch {
            // Expected
        }
        
        // Test very long text
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000)
        let result = try await manager.analyzeScreenshot(
            ocrText: longText,
            appName: "TestApp",
            windowTitle: "Long Document"
        )
        
        assert(result.confidence >= 0 && result.confidence <= 1,
                "Confidence should be in valid range")
        
        // Test special characters
        let specialText = """
        @#$%^&*()_+-=[]{}|;':",./<>?
        SELECT * FROM users WHERE id = 1; DROP TABLE users;--
        <script>alert('XSS')</script>
        """
        
        let specialResult = try await manager.analyzeScreenshot(
            ocrText: specialText,
            appName: "TestApp",
            windowTitle: "Special"
        )
        
        assert(specialResult.detected_activity != "", "Should handle special characters")
    }
    
    func testProductivityInsights() async throws {
        let manager = LLMAnalysisManager()
        let testData = Self.generateSyntheticData()
        
        // Ensure server is ready
        if !manager.isServerRunning {
            manager.checkServerHealth()
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        
        // Generate some analysis history
        for data in testData.prefix(5) {
            do {
                _ = try await manager.analyzeScreenshot(
                    ocrText: data.ocrText,
                    appName: data.appName,
                    windowTitle: data.windowTitle
                )
            } catch {
                print("Skipping failed analysis: \(error)")
            }
        }
        
        // Get insights
        let insights = manager.getFocusInsights()
        
        print("""
        
        📈 Focus Insights:
        ==================
        Focus Percentage: \(String(format: "%.1f%%", insights.focusPercentage * 100))
        Valid Sessions: \(insights.validSessions)
        Total Sessions: \(insights.totalSessions)
        Current Focus: \(insights.currentFocus)
        
        Recent Activities:
        \(insights.recentActivities.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """)
        
        assert(insights.totalSessions > 0, "Should have completed some analyses")
        assert(insights.focusPercentage >= 0, "Focus percentage should be non-negative")
    }
}

// MARK: - Evaluation Report Generator

struct EvaluationReport {
    let timestamp: Date
    let totalTests: Int
    let successfulTests: Int
    let failedTests: Int
    let averageResponseTime: TimeInterval
    let categoryAccuracy: Double
    let scoreAccuracy: Double
    let detailedResults: [TestResult]
    
    struct TestResult {
        let testName: String
        let category: String
        let expectedScore: ClosedRange<Double>
        let actualConfidence: Double
        let responseTime: TimeInterval
        let success: Bool
        let error: String?
    }
    
    func generateMarkdown() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        
        return """
        # LLM Analysis Evaluation Report
        
        **Generated:** \(formatter.string(from: timestamp))
        
        ## Summary
        
        | Metric | Value |
        |--------|-------|
        | Total Tests | \(totalTests) |
        | Successful | \(successfulTests) |
        | Failed | \(failedTests) |
        | Success Rate | \(String(format: "%.1f%%", Double(successfulTests) / Double(totalTests) * 100)) |
        | Avg Response Time | \(String(format: "%.2fs", averageResponseTime)) |
        | Category Accuracy | \(String(format: "%.1f%%", categoryAccuracy * 100)) |
        | Confidence Accuracy | \(String(format: "%.1f%%", scoreAccuracy * 100)) |
        
        ## Detailed Results
        
        | Test | Category | Expected Score | Actual Score | Time | Status |
        |------|----------|---------------|--------------|------|--------|
        \(detailedResults.map { result in
            "| \(result.testName) | \(result.category) | \(String(format: "%.1f-%.1f", result.expectedScore.lowerBound, result.expectedScore.upperBound)) | \(String(format: "%.2f", result.actualConfidence)) | \(String(format: "%.2fs", result.responseTime)) | \(result.success ? "✅" : "❌") |"
        }.joined(separator: "\n"))
        
        ## Performance Analysis
        
        ### Response Time Distribution
        - P50: \(String(format: "%.2fs", calculatePercentile(0.5)))
        - P90: \(String(format: "%.2fs", calculatePercentile(0.9)))
        - P99: \(String(format: "%.2fs", calculatePercentile(0.99)))
        
        ### Category Performance
        \(generateCategoryAnalysis())
        
        ## Recommendations
        
        \(generateRecommendations())
        """
    }
    
    private func calculatePercentile(_ percentile: Double) -> TimeInterval {
        let sorted = detailedResults.map { $0.responseTime }.sorted()
        let index = Int(Double(sorted.count) * percentile)
        return sorted[min(index, sorted.count - 1)]
    }
    
    private func generateCategoryAnalysis() -> String {
        let grouped = Dictionary(grouping: detailedResults) { $0.category }
        
        return grouped.map { category, results in
            let avgConfidence = results.map { $0.actualConfidence }.reduce(0, +) / Double(results.count)
            let successRate = Double(results.filter { $0.success }.count) / Double(results.count)
            
            return """
            **\(category)**
            - Average Confidence: \(String(format: "%.2f", avgConfidence))
            - Success Rate: \(String(format: "%.1f%%", successRate * 100))
            - Sample Count: \(results.count)
            """
        }.joined(separator: "\n\n")
    }
    
    private func generateRecommendations() -> String {
        var recommendations: [String] = []
        
        if averageResponseTime > 3.0 {
            recommendations.append("- Consider optimizing the LLM model or using a faster inference engine")
        }
        
        if categoryAccuracy < 0.8 {
            recommendations.append("- Improve category detection with better prompts or fine-tuning")
        }
        
        if scoreAccuracy < 0.7 {
            recommendations.append("- Calibrate confidence scoring with more training examples")
        }
        
        let failureRate = Double(failedTests) / Double(totalTests)
        if failureRate > 0.1 {
            recommendations.append("- Investigate and fix the high failure rate (\(String(format: "%.1f%%", failureRate * 100)))")
        }
        
        return recommendations.isEmpty ? "System is performing well!" : recommendations.joined(separator: "\n")
    }
    
    func save(to url: URL) throws {
        let markdown = generateMarkdown()
        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }
}