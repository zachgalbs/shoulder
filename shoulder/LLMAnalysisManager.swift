//
//  LLMAnalysisManager.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/3/25.
//

import Foundation
import SwiftUI

enum LLMAnalysisError: Error {
    case serverNotRunning
    case invalidResponse
    case analysisTimeout
    case modelNotAvailable
}

struct AnalysisResult: Codable {
    let is_valid: Bool  // True if activity matches focus
    let explanation: String  // Why it's valid/invalid
    let detected_activity: String  // What the user is actually doing
    let confidence: Double  // How confident the model is (0-1)
    let timestamp: String  // ISO8601 string from Python
}

struct AnalysisRequest: Codable {
    let text: String
    let context: AnalysisContext
    let model: String = "dolphin-mistral:latest"
}

struct AnalysisContext: Codable {
    let app_name: String
    let window_title: String?
    let user_focus: String  // What the user wants to focus on
    let timestamp: Date
}

@MainActor
class LLMAnalysisManager: ObservableObject {
    @Published var isServerRunning = false
    @Published var isAnalyzing = false
    @Published var lastAnalysis: AnalysisResult?
    @Published var analysisHistory: [String: AnalysisResult] = [:]
    @AppStorage("userFocus") var userFocus: String = "Writing code"  // Default focus
    
    private let serverURL = "http://127.0.0.1:8765"  // Use IP instead of localhost to reduce warnings
    private var serverProcess: Process?
    private let analysisQueue = DispatchQueue(label: "com.shoulder.llm.analysis", qos: .background)
    private var pendingAnalyses: [String: AnalysisRequest] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    init() {
        startLLMServer()
        // Delay initial health check to give server time to start
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await checkServerHealth()
        }
    }
    
    deinit {
        serverProcess?.terminate()
        serverProcess = nil
    }
    
    private func startLLMServer() {
        analysisQueue.async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            let venvPython = "\(NSHomeDirectory())/src/shoulder/llm_server/venv/bin/python"
            let serverPath = "\(NSHomeDirectory())/src/shoulder/llm_server/server.py"
            
            // Check if venv exists, otherwise use system python3
            let pythonPath = FileManager.default.fileExists(atPath: venvPython) ? venvPython : "/usr/bin/python3"
            
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [serverPath]
            
            process.environment = ProcessInfo.processInfo.environment
            process.environment?["OLLAMA_HOST"] = "127.0.0.1:11434"
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    print("[LLM Server Output]: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
            
            do {
                print("[LLM] Starting server with Python: \(pythonPath)")
                print("[LLM] Server script: \(serverPath)")
                
                // Check if files exist
                if !FileManager.default.fileExists(atPath: pythonPath) {
                    print("[LLM] ERROR: Python not found at \(pythonPath)")
                    return
                }
                if !FileManager.default.fileExists(atPath: serverPath) {
                    print("[LLM] ERROR: Server script not found at \(serverPath)")
                    return
                }
                
                try process.run()
                self.serverProcess = process
                print("[LLM] Server process started, PID: \(process.processIdentifier)")
                
                // Give server more time to start
                Thread.sleep(forTimeInterval: 4.0)
                
                Task { @MainActor in
                    // Retry health check with exponential backoff
                    for attempt in 1...3 {
                        self.checkServerHealth()
                        if self.isServerRunning { break }
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                    }
                }
            } catch {
                print("[LLM] ERROR: Failed to start LLM server: \(error)")
            }
        }
    }
    
    private func stopLLMServer() {
        serverProcess?.terminate()
        serverProcess = nil
        isServerRunning = false
    }
    
    func checkServerHealth() {
        Task {
            guard let url = URL(string: "\(serverURL)/health") else { 
                print("[LLM] Invalid health check URL")
                return 
            }
            
            print("[LLM] Checking server health at \(serverURL)/health")
            
            do {
                let (data, response) = try await urlSession.data(from: url)
                if let httpResponse = response as? HTTPURLResponse {
                    print("[LLM] Health check response: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 {
                        isServerRunning = true
                        if let responseText = String(data: data, encoding: .utf8) {
                            print("[LLM] Server is healthy: \(responseText)")
                        }
                    } else {
                        isServerRunning = false
                        print("[LLM] Server returned non-200 status: \(httpResponse.statusCode)")
                    }
                }
            } catch {
                isServerRunning = false
                print("[LLM] Health check failed: \(error.localizedDescription)")
            }
        }
    }
    
    func analyzeScreenshot(ocrText: String, appName: String, windowTitle: String?) async throws -> AnalysisResult {
        print("\n[LLM] 🧠 === LLM Analysis Pipeline ===")
        print("[LLM] 🧠 Step A: Checking server status...")
        
        guard isServerRunning else {
            print("[LLM] ❌ Server not running!")
            throw LLMAnalysisError.serverNotRunning
        }
        
        print("[LLM] 🧠 Step B: Server is running, preparing request...")
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let context = AnalysisContext(
            app_name: appName,
            window_title: windowTitle,
            user_focus: userFocus,
            timestamp: Date()
        )
        
        // Prepare the request
        let truncatedText = String(ocrText.prefix(2000)) // Limit to 2000 chars
        print("[LLM] 🧠 Step C: Request context:")
        print("[LLM]    - App: \(appName)")
        print("[LLM]    - Window: \(windowTitle ?? "none")")
        print("[LLM]    - User Focus: \(userFocus)")
        print("[LLM]    - Text length: \(truncatedText.count) chars")
        print("[LLM]    - Text preview: \(String(truncatedText.prefix(100)))...")
        
        let request = AnalysisRequest(text: truncatedText, context: context)
        
        guard let url = URL(string: "\(serverURL)/analyze") else {
            print("[LLM] ❌ Invalid URL")
            throw LLMAnalysisError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData
        
        print("[LLM] 🧠 Step D: Sending POST to \(serverURL)/analyze")
        print("[LLM]    - Request size: \(requestData.count) bytes")
        print("[LLM]    - Model: \(request.model)")
        
        let startTime = Date()
        let (data, response) = try await urlSession.data(for: urlRequest)
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("[LLM] 🧠 Step E: Response received in \(String(format: "%.2f", elapsed))s")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[LLM] ❌ Invalid response type")
            throw LLMAnalysisError.invalidResponse
        }
        
        print("[LLM]    - Status code: \(httpResponse.statusCode)")
        print("[LLM]    - Response size: \(data.count) bytes")
        
        guard httpResponse.statusCode == 200 else {
            print("[LLM] ❌ Non-200 status: \(httpResponse.statusCode)")
            if let errorText = String(data: data, encoding: .utf8) {
                print("[LLM] ❌ Error: \(errorText)")
            }
            throw LLMAnalysisError.invalidResponse
        }
        
        print("[LLM] 🧠 Step F: Decoding response...")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(AnalysisResult.self, from: data)
        
        print("[LLM] 🧠 Step G: Analysis decoded successfully!")
        print("[LLM] ✅ === Analysis Complete ===")
        print("[LLM]    Focus: \(userFocus)")
        print("[LLM]    Valid: \(result.is_valid ? "✅ YES" : "❌ NO")")
        print("[LLM]    Activity: \(result.detected_activity)")
        print("[LLM]    Explanation: \(result.explanation)")
        print("[LLM]    Confidence: \(Int(result.confidence * 100))%")
        
        lastAnalysis = result
        analysisHistory[appName] = result
        
        return result
    }
    
    
    private func saveAnalysisResult(_ result: AnalysisResult, for session: Item) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: session.startTime)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let timeString = timeFormatter.string(from: session.startTime)
        
        // Store in ~/src/shoulder/analyses/ directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let analysisDir = homeDir.appendingPathComponent("src/shoulder/analyses/\(dateString)")
        let analysisFile = analysisDir.appendingPathComponent("analysis-\(timeString).json")
        
        do {
            try FileManager.default.createDirectory(at: analysisDir, withIntermediateDirectories: true, attributes: nil)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(result)
            
            try data.write(to: analysisFile)
            print("[LLM] Analysis saved to: \(analysisFile.path)")
        } catch {
            print("[LLM] Failed to save analysis: \(error)")
        }
    }
    
    func getFocusInsights(for date: Date = Date()) -> FocusInsights {
        let calendar = Calendar.current
        
        let relevantAnalyses = analysisHistory.values.filter { analysis in
            // Parse ISO8601 timestamp string to Date
            let formatter = ISO8601DateFormatter()
            if let analysisDate = formatter.date(from: analysis.timestamp) {
                return calendar.isDate(analysisDate, inSameDayAs: date)
            }
            return false
        }
        
        let validCount = relevantAnalyses.filter { $0.is_valid }.count
        let totalCount = relevantAnalyses.count
        let focusPercentage = totalCount > 0 ? Double(validCount) / Double(totalCount) : 0.0
        
        let recentActivities = relevantAnalyses.suffix(5).map { $0.detected_activity }
        
        return FocusInsights(
            focusPercentage: focusPercentage,
            validSessions: validCount,
            totalSessions: totalCount,
            currentFocus: userFocus,
            recentActivities: recentActivities
        )
    }
}

struct FocusInsights {
    let focusPercentage: Double
    let validSessions: Int
    let totalSessions: Int
    let currentFocus: String
    let recentActivities: [String]
}

struct LLMStatusView: View {
    @ObservedObject var llmManager: LLMAnalysisManager
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: llmManager.isServerRunning ? "brain" : "brain.head.profile")
                .foregroundColor(llmManager.isServerRunning ? DesignSystem.Colors.activeGreen : DesignSystem.Colors.textTertiary)
                .font(.caption)
            
            if llmManager.isAnalyzing {
                // Replace ProgressView with a simple animated dot
                Circle()
                    .fill(DesignSystem.Colors.accentBlue)
                    .frame(width: 6, height: 6)
                    .opacity(llmManager.isAnalyzing ? 1.0 : 0.3)
                Text("Analyzing...")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                Text(llmManager.isServerRunning ? "AI Ready" : "AI Offline")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}