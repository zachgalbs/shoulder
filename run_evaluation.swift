#!/usr/bin/env swift
//
// LLM Analysis Evaluation Runner
// Runs comprehensive evaluation of the LLM analysis system
//

import Foundation

// MARK: - Configuration

struct EvaluationConfig {
    static let serverURL = "http://localhost:8765"
    static let numberOfTests = 50
    static let parallelRequests = 5
    static let timeoutSeconds: TimeInterval = 30
}

// MARK: - Test Data Generation

struct TestCase {
    let id: String
    let category: String
    let appName: String
    let windowTitle: String
    let ocrText: String
    let expectedScoreRange: ClosedRange<Double>
    let expectedKeywords: [String]
}

class TestDataGenerator {
    
    static func generateTestCases(count: Int) -> [TestCase] {
        var testCases: [TestCase] = []
        
        let categories = [
            "Programming": (7.0...9.5, ["function", "class", "import", "def", "struct"]),
            "Communication": (5.0...7.0, ["email", "message", "chat", "meeting", "team"]),
            "Research": (6.5...8.5, ["search", "documentation", "stackoverflow", "api", "guide"]),
            "Documentation": (7.0...8.5, ["document", "report", "notes", "specification", "overview"]),
            "Media": (2.0...4.0, ["video", "youtube", "music", "streaming", "playlist"]),
            "System": (4.0...6.0, ["finder", "settings", "terminal", "activity", "process"])
        ]
        
        let programmingTexts = [
            """
            func calculateMetrics(data: [Double]) -> Statistics {
                let mean = data.reduce(0, +) / Double(data.count)
                let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(data.count)
                return Statistics(mean: mean, variance: variance, stdDev: sqrt(variance))
            }
            """,
            """
            class DataProcessor {
                private var cache: [String: Any] = [:]
                
                func process(_ input: String) async throws -> ProcessedData {
                    if let cached = cache[input] as? ProcessedData {
                        return cached
                    }
                    let result = try await performProcessing(input)
                    cache[input] = result
                    return result
                }
            }
            """,
            """
            import SwiftUI
            
            struct ContentView: View {
                @State private var selectedTab = 0
                
                var body: some View {
                    TabView(selection: $selectedTab) {
                        HomeView().tabItem { Label("Home", systemImage: "house") }.tag(0)
                        SettingsView().tabItem { Label("Settings", systemImage: "gear") }.tag(1)
                    }
                }
            }
            """
        ]
        
        let communicationTexts = [
            """
            From: team@company.com
            Subject: Sprint Planning Meeting
            
            Hi everyone,
            
            Let's meet tomorrow at 10 AM to discuss the upcoming sprint goals.
            Please review the backlog items before the meeting.
            
            Agenda:
            - Sprint goal definition
            - Story estimation
            - Resource allocation
            
            Thanks,
            John
            """,
            """
            Slack - #engineering
            
            Sarah: Hey team, PR #234 is ready for review
            Mike: I'll take a look!
            Sarah: Thanks! The main changes are in the authentication module
            You: LGTM, approved ✅
            Bot: Build #567 passed successfully
            """
        ]
        
        let researchTexts = [
            """
            SwiftUI Navigation - Apple Developer Documentation
            
            NavigationStack
            A view that displays a root view and enables navigation.
            
            Declaration:
            struct NavigationStack<Data, Root> where Root : View
            
            Overview:
            Use NavigationStack to present a stack of views. Users navigate by selecting NavigationLink views.
            
            Example:
            NavigationStack {
                List(items) { item in
                    NavigationLink(item.name, destination: DetailView(item))
                }
            }
            """,
            """
            Stack Overflow - How to handle async/await in Swift?
            
            Question (234 votes):
            I'm trying to understand the new async/await syntax in Swift. How do I properly handle errors?
            
            Answer (456 votes):
            You can use try/catch with async/await:
            
            func fetchData() async throws -> Data {
                let url = URL(string: "https://api.example.com")!
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
            """
        ]
        
        // Generate test cases
        for i in 0..<count {
            let categoryInfo = categories.randomElement()!
            let category = String(categoryInfo.key)
            let (scoreRange, keywords) = categoryInfo.value
            
            var ocrText = ""
            var appName = ""
            var windowTitle = ""
            
            switch category {
            case "Programming":
                ocrText = programmingTexts.randomElement()!
                appName = ["Xcode", "Visual Studio Code", "IntelliJ IDEA"].randomElement()!
                windowTitle = ["main.swift", "ViewController.swift", "AppDelegate.swift"].randomElement()!
            case "Communication":
                ocrText = communicationTexts.randomElement()!
                appName = ["Slack", "Mail", "Teams", "Discord"].randomElement()!
                windowTitle = ["#general", "Inbox", "Team Chat"].randomElement()!
            case "Research":
                ocrText = researchTexts.randomElement()!
                appName = ["Safari", "Chrome", "Firefox"].randomElement()!
                windowTitle = ["Apple Developer", "Stack Overflow", "Documentation"].randomElement()!
            default:
                ocrText = "Generic text for \(category) category"
                appName = "TestApp"
                windowTitle = "Test Window"
            }
            
            testCases.append(TestCase(
                id: "test_\(String(format: "%04d", i))",
                category: category,
                appName: appName,
                windowTitle: windowTitle,
                ocrText: ocrText,
                expectedScoreRange: scoreRange,
                expectedKeywords: keywords
            ))
        }
        
        return testCases
    }
}

// MARK: - Analysis Client

class AnalysisClient {
    
    struct AnalysisRequest: Codable {
        let text: String
        let context: Context
        
        struct Context: Codable {
            let app_name: String
            let window_title: String?
            let duration_seconds: Int
            let timestamp: String
        }
    }
    
    struct AnalysisResponse: Codable {
        let summary: String
        let category: String
        let productivity_score: Double
        let key_activities: [String]
        let processing_time_ms: Double?
        let confidence: Double?
    }
    
    static func analyze(testCase: TestCase) async throws -> (response: AnalysisResponse, duration: TimeInterval) {
        let url = URL(string: "\(EvaluationConfig.serverURL)/analyze")!
        
        let request = AnalysisRequest(
            text: testCase.ocrText,
            context: AnalysisRequest.Context(
                app_name: testCase.appName,
                window_title: testCase.windowTitle,
                duration_seconds: 120,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = EvaluationConfig.timeoutSeconds
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let analysisResponse = try decoder.decode(AnalysisResponse.self, from: data)
        
        return (analysisResponse, duration)
    }
}

// MARK: - Evaluation Metrics

struct EvaluationMetrics {
    var totalTests = 0
    var successfulTests = 0
    var failedTests = 0
    var categoryMatches = 0
    var scoreInRangeCount = 0
    var responseTimes: [TimeInterval] = []
    var scoresByCategory: [String: [Double]] = [:]
    var errors: [String: Int] = [:]
    
    var successRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(successfulTests) / Double(totalTests)
    }
    
    var categoryAccuracy: Double {
        guard successfulTests > 0 else { return 0 }
        return Double(categoryMatches) / Double(successfulTests)
    }
    
    var scoreAccuracy: Double {
        guard successfulTests > 0 else { return 0 }
        return Double(scoreInRangeCount) / Double(successfulTests)
    }
    
    var averageResponseTime: TimeInterval {
        guard !responseTimes.isEmpty else { return 0 }
        return responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
    
    var p95ResponseTime: TimeInterval {
        guard !responseTimes.isEmpty else { return 0 }
        let sorted = responseTimes.sorted()
        let index = Int(Double(sorted.count) * 0.95)
        return sorted[min(index, sorted.count - 1)]
    }
    
    func generateReport() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        
        var report = """
        ============================================================
        LLM Analysis Evaluation Report
        Generated: \(formatter.string(from: Date()))
        ============================================================
        
        SUMMARY
        -------
        Total Tests: \(totalTests)
        Successful: \(successfulTests)
        Failed: \(failedTests)
        Success Rate: \(String(format: "%.1f%%", successRate * 100))
        
        ACCURACY METRICS
        ----------------
        Category Accuracy: \(String(format: "%.1f%%", categoryAccuracy * 100))
        Score Accuracy: \(String(format: "%.1f%%", scoreAccuracy * 100))
        
        PERFORMANCE METRICS
        -------------------
        Average Response Time: \(String(format: "%.2fs", averageResponseTime))
        P95 Response Time: \(String(format: "%.2fs", p95ResponseTime))
        
        CATEGORY BREAKDOWN
        ------------------
        """
        
        for (category, scores) in scoresByCategory.sorted(by: { $0.key < $1.key }) {
            let avgScore = scores.reduce(0, +) / Double(scores.count)
            report += "\n\(category): Avg Score = \(String(format: "%.1f", avgScore)), Count = \(scores.count)"
        }
        
        if !errors.isEmpty {
            report += "\n\nERRORS\n------"
            for (error, count) in errors.sorted(by: { $0.value > $1.value }) {
                report += "\n\(error): \(count) occurrences"
            }
        }
        
        report += "\n\n============================================================\n"
        
        return report
    }
}

// MARK: - Main Evaluation Runner

@main
struct EvaluationRunner {
    
    static func main() async {
        print("🚀 Starting LLM Analysis Evaluation")
        print("====================================\n")
        
        // Check server health first
        if !(await checkServerHealth()) {
            print("❌ Server is not healthy. Please start the server first.")
            return
        }
        
        // Generate test cases
        print("📝 Generating \(EvaluationConfig.numberOfTests) test cases...")
        let testCases = TestDataGenerator.generateTestCases(count: EvaluationConfig.numberOfTests)
        print("✅ Test cases generated\n")
        
        // Run evaluation
        var metrics = EvaluationMetrics()
        
        print("🔄 Running evaluation...")
        print("Progress:")
        
        for (index, testCase) in testCases.enumerated() {
            metrics.totalTests += 1
            
            do {
                let (response, duration) = try await AnalysisClient.analyze(testCase: testCase)
                
                metrics.successfulTests += 1
                metrics.responseTimes.append(duration)
                
                // Check category match
                if response.category == testCase.category {
                    metrics.categoryMatches += 1
                }
                
                // Check score in range
                if testCase.expectedScoreRange.contains(response.productivity_score) {
                    metrics.scoreInRangeCount += 1
                }
                
                // Track scores by category
                if metrics.scoresByCategory[response.category] == nil {
                    metrics.scoresByCategory[response.category] = []
                }
                metrics.scoresByCategory[response.category]?.append(response.productivity_score)
                
                // Progress indicator
                if (index + 1) % 10 == 0 {
                    print("  [\(index + 1)/\(testCases.count)] completed")
                }
                
            } catch {
                metrics.failedTests += 1
                let errorKey = String(describing: error)
                metrics.errors[errorKey, default: 0] += 1
            }
        }
        
        print("\n✅ Evaluation completed!\n")
        
        // Generate and print report
        let report = metrics.generateReport()
        print(report)
        
        // Save report to file
        let reportPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm_evaluation_\(Date().timeIntervalSince1970).txt")
        
        do {
            try report.write(to: reportPath, atomically: true, encoding: .utf8)
            print("📄 Report saved to: \(reportPath.path)")
        } catch {
            print("⚠️ Failed to save report: \(error)")
        }
    }
    
    static func checkServerHealth() async -> Bool {
        guard let url = URL(string: "\(EvaluationConfig.serverURL)/health") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("⚠️ Server health check failed: \(error)")
        }
        
        return false
    }
}