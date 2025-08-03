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
    let summary: String
    let category: String
    let productivity_score: Double
    let key_activities: [String]
    let suggestions: [String]?
    let timestamp: Date
}

struct AnalysisRequest: Codable {
    let text: String
    let context: AnalysisContext
    let model: String = "dolphin-mistral:latest"
}

struct AnalysisContext: Codable {
    let app_name: String
    let window_title: String?
    let duration_seconds: Int
    let timestamp: Date
}

@MainActor
class LLMAnalysisManager: ObservableObject {
    @Published var isServerRunning = false
    @Published var isAnalyzing = false
    @Published var lastAnalysis: AnalysisResult?
    @Published var analysisHistory: [String: AnalysisResult] = [:]
    
    private let serverURL = "http://localhost:8765"
    private var serverProcess: Process?
    private let analysisQueue = DispatchQueue(label: "com.shoulder.llm.analysis", qos: .background)
    private var pendingAnalyses: [String: AnalysisRequest] = [:]
    
    init() {
        startLLMServer()
        checkServerHealth()
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
                
                Thread.sleep(forTimeInterval: 3.0)
                
                Task { @MainActor in
                    self.checkServerHealth()
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
                let (data, response) = try await URLSession.shared.data(from: url)
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
    
    func analyzeScreenshot(ocrText: String, appName: String, windowTitle: String?, duration: TimeInterval) async throws -> AnalysisResult {
        guard isServerRunning else {
            throw LLMAnalysisError.serverNotRunning
        }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let context = AnalysisContext(
            app_name: appName,
            window_title: windowTitle,
            duration_seconds: Int(duration),
            timestamp: Date()
        )
        
        let request = AnalysisRequest(text: ocrText, context: context)
        
        guard let url = URL(string: "\(serverURL)/analyze") else {
            throw LLMAnalysisError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMAnalysisError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(AnalysisResult.self, from: data)
        
        lastAnalysis = result
        analysisHistory[appName] = result
        
        return result
    }
    
    func analyzeSession(_ session: Item, ocrText: String?) async {
        guard let ocrText = ocrText, !ocrText.isEmpty else { return }
        
        do {
            let result = try await analyzeScreenshot(
                ocrText: ocrText,
                appName: session.appName,
                windowTitle: session.windowTitle,
                duration: session.duration ?? 0
            )
            
            await MainActor.run {
                saveAnalysisResult(result, for: session)
            }
        } catch {
            print("Analysis failed: \(error)")
        }
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
    
    func getProductivityInsights(for date: Date = Date()) -> ProductivityInsights {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let relevantAnalyses = analysisHistory.values.filter { analysis in
            calendar.isDate(analysis.timestamp, inSameDayAs: date)
        }
        
        let avgScore = relevantAnalyses.isEmpty ? 0.0 :
            relevantAnalyses.map { $0.productivity_score }.reduce(0, +) / Double(relevantAnalyses.count)
        
        let categories = Dictionary(grouping: relevantAnalyses) { $0.category }
            .mapValues { $0.count }
        
        let topActivities = relevantAnalyses
            .flatMap { $0.key_activities }
            .reduce(into: [:]) { counts, activity in
                counts[activity, default: 0] += 1
            }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        
        return ProductivityInsights(
            averageScore: avgScore,
            categoryBreakdown: categories,
            topActivities: topActivities,
            totalAnalyses: relevantAnalyses.count
        )
    }
}

struct ProductivityInsights {
    let averageScore: Double
    let categoryBreakdown: [String: Int]
    let topActivities: [String]
    let totalAnalyses: Int
}

struct LLMStatusView: View {
    @ObservedObject var llmManager: LLMAnalysisManager
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: llmManager.isServerRunning ? "brain" : "brain.slash")
                .foregroundColor(llmManager.isServerRunning ? DesignSystem.Colors.activeGreen : DesignSystem.Colors.textTertiary)
                .font(.caption)
            
            if llmManager.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.7)
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