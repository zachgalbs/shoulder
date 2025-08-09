//
//  MLXLLMManager.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/6/25.
//

import Foundation
import SwiftUI
import MLX
import MLXNN
import MLXRandom
import MLXOptimizers
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
            
            print("[MLX] ✅ Language model loaded successfully: \(selectedModel)")
            
        } catch {
            modelLoadingMessage = "Failed to load model: \(error.localizedDescription)"
            print("[MLX] ❌ Model loading failed: \(error)")
            
            self.isModelLoaded = false
            self.isModelReady = false
        }
    }
    
    func analyzeScreenshot(ocrText: String, appName: String, windowTitle: String?) async throws -> MLXAnalysisResult {
        print("\n[MLX] 🧠 === MLX Analysis Pipeline ===")
        print("[MLX] 🧠 Step A: Checking model status...")
        
        guard isModelReady else {
            print("[MLX] ❌ Model not ready!")
            throw MLXLLMError.modelNotLoaded
        }
        
        print("[MLX] 🧠 Step B: Model is ready, preparing analysis...")
        
        isAnalyzing = true
        defer { 
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }
        
        let truncatedText = String(ocrText.prefix(1500))
        
        print("[MLX] 🧠 Step C: Request context:")
        print("[MLX]    - App: \(appName)")
        print("[MLX]    - Window: \(windowTitle ?? "none")")
        print("[MLX]    - User Focus: \(userFocus)")
        print("[MLX]    - Text length: \(truncatedText.count) chars")
        
        print("[MLX] 🧠 Step D: Generating response...")
        let startTime = Date()
        
        let analysis: MLXAnalysisResult
        
        if let container = modelContainer {
            // Use MLX model for analysis
            print("[MLX] 🧠 Using MLX model for inference...")
            analysis = try await performMLXAnalysis(
                container: container,
                text: truncatedText,
                appName: appName,
                windowTitle: windowTitle
            )
        } else {
            // No fallback - require model to be loaded
            print("[MLX] ❌ Model not loaded")
            throw MLXLLMError.modelNotLoaded
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("[MLX] 🧠 Step E: Response generated in \(String(format: "%.2f", elapsed))s")
        
        print("[MLX] 🧠 Step F: Analysis complete!")
        print("[MLX] ✅ === Analysis Complete ===")
        print("[MLX]    Focus: \(userFocus)")
        print("[MLX]    Valid: \(analysis.is_valid ? "✅ YES" : "❌ NO")")
        print("[MLX]    Activity: \(analysis.detected_activity)")
        print("[MLX]    Explanation: \(analysis.explanation)")
        print("[MLX]    Confidence: \(Int(analysis.confidence * 100))%")
        
        lastAnalysis = analysis
        analysisHistory[appName] = analysis
        
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
            "detected_activity": "brief description of what the user is doing",
            "explanation": "brief explanation of why this does or doesn't align with their focus",
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
            
            // If JSON parsing fails, try to extract meaningful content
            print("[MLX] ⚠️ Failed to parse JSON response, using fallback parsing")
            
            // Special handling for "Debugging" focus
            let isDebuggingFocus = userFocus.lowercased().contains("debug")
            let hasCodeEvidence = detectCodeEvidence(text: text, appName: appName)
            
            let isValid: Bool
            let confidence: Double
            
            if isDebuggingFocus && hasCodeEvidence {
                // Lenient rule for debugging focus with code evidence
                isValid = true
                confidence = 0.85
            } else {
                isValid = generatedText.lowercased().contains("aligns") || generatedText.lowercased().contains("focused")
                confidence = 0.5
            }
            
            let detectedActivity = detectActivity(text: text, appName: appName)
            let explanation = isDebuggingFocus && hasCodeEvidence ? 
                "Code-related activity detected, aligned with debugging focus." : 
                "Analysis based on \(appName) usage."
            
            return MLXAnalysisResult(
                is_valid: isValid,
                explanation: explanation,
                detected_activity: detectedActivity,
                confidence: confidence,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
        }
        
        var finalIsValid = isValid
        var finalConfidence = (json["confidence"] as? Double) ?? 0.7
        var finalExplanation = explanation
        
        // Apply lenient "Debugging" focus rule even when JSON parsing succeeds
        let isDebuggingFocus = userFocus.lowercased().contains("debug")
        if isDebuggingFocus && !isValid {
            // Check if there's code evidence that the model might have missed
            let hasCodeEvidence = detectCodeEvidence(text: text, appName: appName)
            if hasCodeEvidence {
                // Override the model's decision for debugging focus with code evidence
                finalIsValid = true
                finalConfidence = max(finalConfidence, 0.75) // Ensure at least 75% confidence
                finalExplanation = "Code-related activity detected. \(explanation)"
                print("[MLX] 🔧 Applied lenient debugging rule: overriding model decision")
            }
        }
        
        return MLXAnalysisResult(
            is_valid: finalIsValid,
            explanation: finalExplanation,
            detected_activity: detectedActivity,
            confidence: finalConfidence,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    private func detectCodeEvidence(text: String, appName: String) -> Bool {
        let textLower = text.lowercased()
        let appLower = appName.lowercased()
        
        // Check for development-related applications
        let devApps = ["xcode", "vscode", "visual studio", "sublime", "atom", "intellij", 
                       "terminal", "iterm", "console", "github", "sourcetree", "tower"]
        if devApps.contains(where: { appLower.contains($0) }) {
            return true
        }
        
        // Check for programming language keywords
        let codeKeywords = ["function", "class", "struct", "import", "export", "return", 
                           "if", "else", "for", "while", "var", "let", "const", "def", 
                           "public", "private", "async", "await", "try", "catch", "throw",
                           "{", "}", "[", "]", "(", ")", "=>", "->", "::", "//", "/*", "*/",
                           "git", "npm", "yarn", "pip", "cargo", "swift", "python", "javascript",
                           "typescript", "rust", "java", "cpp", "csharp", "ruby", "golang"]
        
        let keywordCount = codeKeywords.filter { textLower.contains($0) }.count
        
        // If we find at least 2 code-related keywords, consider it code evidence
        return keywordCount >= 2
    }
    
    private func detectActivity(text: String, appName: String) -> String {
        let textLower = text.lowercased()
        let appLower = appName.lowercased()
        
        if appLower.contains("xcode") || appLower.contains("vscode") || 
           textLower.contains("function") || textLower.contains("class") {
            return "Programming/Development"
        } else if appLower.contains("safari") || appLower.contains("chrome") {
            return "Web Browsing"
        } else if appLower.contains("slack") || appLower.contains("messages") {
            return "Communication"
        } else if appLower.contains("pages") || appLower.contains("word") {
            return "Writing/Documentation"
        } else {
            return "General Computer Use"
        }
    }
    
    private func saveAnalysisResult(_ result: MLXAnalysisResult, appName: String) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let timeString = timeFormatter.string(from: Date())
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let analysisDir = homeDir.appendingPathComponent("src/shoulder/analyses/\(dateString)")
        let analysisFile = analysisDir.appendingPathComponent("analysis-\(timeString).json")
        
        do {
            try FileManager.default.createDirectory(at: analysisDir, withIntermediateDirectories: true, attributes: nil)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(result)
            
            try data.write(to: analysisFile)
            print("[MLX] Analysis saved to: \(analysisFile.path)")
        } catch {
            print("[MLX] Failed to save analysis: \(error)")
        }
    }
    
    func getFocusInsights(for date: Date = Date()) -> FocusInsights {
        let calendar = Calendar.current
        
        let relevantAnalyses = analysisHistory.values.filter { analysis in
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

