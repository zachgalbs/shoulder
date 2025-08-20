//
//  MLXLLMManager.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/6/25.
//

import Foundation
import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon

enum MLXLLMError: Error {
    case modelNotLoaded
    case invalidResponse
    case analysisTimeout
    case modelDownloadFailed
}

struct MLXAnalysisResult: Codable {
    let is_valid: Bool
    let explanation: String
    let detected_activity: String
    let confidence: Double
    let timestamp: String
    let analysis_source: String  // "llm" for actual AI analysis, "error" for failures
}

@MainActor
class MLXLLMManager: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isModelReady = false
    @Published var isAnalyzing = false
    @Published var lastAnalysis: MLXAnalysisResult?
    @Published var analysisHistory: [String: MLXAnalysisResult] = [:]
    @Published var modelLoadingMessage = "Initializing MLX..."
    @AppStorage("userFocus") var userFocus: String = "Writing code"
    @AppStorage("selectedModel") var selectedModel: String = "mlx-community/Qwen2.5-3B-Instruct-4bit"
    
    private let analysisQueue = DispatchQueue(label: "com.shoulder.mlx.analysis", qos: .userInitiated)
    private var modelContainer: ModelContainer?
    
    init() {
        Task {
            await loadModel()
        }
    }
    
    func loadModel() async {
        modelLoadingMessage = "Loading MLX model..."
        
        do {
            modelLoadingMessage = "Preparing language model..."
            
            // Set GPU cache limit for better performance
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024 * 1024) // 20GB cache
            
            // Use the simple API to load the model
            modelLoadingMessage = "Loading \(selectedModel)..."
            
            // Load model container directly using MLXLMCommon
            modelContainer = try await loadModelContainer(id: selectedModel) { progress in
                // Update progress on main thread
                let percentage = Int(progress.fractionCompleted * 100)
                Task { @MainActor in
                    self.modelLoadingMessage = "Downloading model: \(percentage)%"
                }
            }
            
            self.isModelLoaded = true
            self.isModelReady = true
            self.modelLoadingMessage = "MLX model ready!"
            
            
        } catch {
            modelLoadingMessage = "Failed to load model: \(error.localizedDescription)"
            
            self.isModelLoaded = false
            self.isModelReady = false
        }
    }
    
    func analyzeScreenshot(ocrText: String, appName: String, windowTitle: String?) async throws -> MLXAnalysisResult {
        
        guard isModelReady else {
            throw MLXLLMError.modelNotLoaded
        }
        
        
        isAnalyzing = true
        defer { 
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }
        
        let truncatedText = String(ocrText.prefix(1500))
        
        let analysis: MLXAnalysisResult
        
        if let container = modelContainer {
            // Use MLX model for analysis
            analysis = try await performMLXAnalysis(
                container: container,
                text: truncatedText,
                appName: appName,
                windowTitle: windowTitle
            )
        } else {
            // No fallback - require model to be loaded
            throw MLXLLMError.modelNotLoaded
        }
        
        // Analysis completed - timing calculation removed as it was unused
        
        lastAnalysis = analysis
        analysisHistory[appName] = analysis
        
        // Send notification for blocking manager to handle
        NotificationCenter.default.post(
            name: .mlxAnalysisCompleted,
            object: nil,
            userInfo: ["analysis": analysis, "appName": appName]
        )
        
        await saveAnalysisResult(analysis, appName: appName)
        
        return analysis
    }
    
    private func performMLXAnalysis(container: ModelContainer, text: String, appName: String, windowTitle: String?) async throws -> MLXAnalysisResult {
        // Create a prompt for the LLM to analyze the user's activity
        let prompt = """
        You are an AI assistant analyzing user activity. The user's stated focus is: "\(userFocus)".
        
        Current application: \(appName)
        Window title: \(windowTitle ?? "N/A")
        Screen content (OCR text, first 500 chars): \(String(text.prefix(500)))
        
        IMPORTANT RULE: If the user's focus is "Debugging" and there is ANY evidence of code, programming languages, development tools, or technical content in the screen content, consider the activity as aligned (is_valid: true) with high confidence.
        
        Based on this information, provide a JSON response with the following structure:
        {
            "is_valid": true/false (whether the activity aligns with the user's focus),
            "detected_activity": "what user is doing (3-5 words max)",
            "explanation": "2-7 word reason (e.g., 'browsing social media', 'reading documentation', 'watching videos')",
            "confidence": 0.0-1.0 (confidence in the assessment)
        }
        
        Respond ONLY with valid JSON, no additional text.
        """
        
        // Create a chat session for the analysis
        let session = ChatSession(container)
        
        // Generate response using the LLM
        let generatedText = try await session.respond(to: prompt)
        
        // Parse the JSON response
        guard let jsonData = generatedText.data(using: String.Encoding.utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let isValid = json["is_valid"] as? Bool,
              let detectedActivity = json["detected_activity"] as? String,
              let explanation = json["explanation"] as? String else {
            
            // If JSON parsing fails, throw an error instead of using fallback
            throw MLXLLMError.invalidResponse
        }
        
        let confidence = (json["confidence"] as? Double) ?? 0.7
        
        // Return the LLM's analysis without any overrides or modifications
        return MLXAnalysisResult(
            is_valid: isValid,
            explanation: explanation,
            detected_activity: detectedActivity,
            confidence: confidence,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            analysis_source: "llm"
        )
    }
    
    
    private func saveAnalysisResult(_ result: MLXAnalysisResult, appName: String) async {
        let dateString = DateFormatters.fileDate.string(from: Date())
        let timeString = DateFormatters.fileTime.string(from: Date())
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let analysisDir = homeDir.appendingPathComponent("src/shoulder/analyses/\(dateString)")
        let analysisFile = analysisDir.appendingPathComponent("analysis-\(timeString).json")
        
        do {
            try FileManager.default.createDirectory(at: analysisDir, withIntermediateDirectories: true, attributes: nil)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(result)
            
            try data.write(to: analysisFile)
        } catch {
        }
    }
    
    func switchModel(to modelID: String) async {
        selectedModel = modelID
        isModelLoaded = false
        isModelReady = false
        
        // Clean up existing model
        modelContainer = nil
        
        // Load new model
        await loadModel()
    }
    
    deinit {
        modelContainer = nil
    }
}

struct MLXStatusView: View {
    @ObservedObject var mlxManager: MLXLLMManager
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: mlxManager.isModelReady ? "brain" : "brain.head.profile")
                .foregroundColor(mlxManager.isModelReady ? DesignSystem.Colors.activeGreen : DesignSystem.Colors.textTertiary)
                .font(.caption)
            
            if mlxManager.isAnalyzing {
                Circle()
                    .fill(DesignSystem.Colors.accentBlue)
                    .frame(width: 6, height: 6)
                Text("Analyzing...")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else if !mlxManager.isModelReady {
                Text(mlxManager.modelLoadingMessage)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                Text("AI Ready")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}


