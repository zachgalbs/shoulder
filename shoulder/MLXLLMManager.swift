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
    case apiKeyRequired
    case networkError
    case unsupportedModel
}

enum ModelType {
    case local
    case remote
}

struct AIModelConfiguration {
    let id: String
    let displayName: String
    let type: ModelType
    let description: String
    
    static let availableModels = [
        AIModelConfiguration(
            id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
            displayName: "Qwen2.5-3B (Local)",
            type: .local,
            description: "Fast local model using MLX"
        ),
        AIModelConfiguration(
            id: "gpt-5",
            displayName: "GPT-5",
            type: .remote,
            description: "OpenAI's most advanced model for complex reasoning"
        ),
        AIModelConfiguration(
            id: "gpt-5-mini",
            displayName: "GPT-5 Mini",
            type: .remote,
            description: "Balanced performance and cost for most applications"
        ),
        AIModelConfiguration(
            id: "gpt-5-nano",
            displayName: "GPT-5 Nano",
            type: .remote,
            description: "Lightweight and economical for real-time tasks"
        )
    ]
    
    static func getConfiguration(for modelId: String) -> AIModelConfiguration? {
        return availableModels.first { $0.id == modelId }
    }
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
    @AppStorage("openaiApiKey") var openaiApiKey: String = ""
    
    private let analysisQueue = DispatchQueue(label: "com.shoulder.mlx.analysis", qos: .userInitiated)
    private var modelContainer: ModelContainer?
    
    init() {
        Task {
            await loadModel()
        }
    }
    
    func loadModel() async {
        guard let config = AIModelConfiguration.getConfiguration(for: selectedModel) else {
            modelLoadingMessage = "Unknown model configuration"
            self.isModelLoaded = false
            self.isModelReady = false
            return
        }
        
        switch config.type {
        case .local:
            await loadMLXModel()
        case .remote:
            await validateRemoteModel()
        }
    }
    
    private func loadMLXModel() async {
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
    
    private func validateRemoteModel() async {
        modelLoadingMessage = "Validating remote model..."
        
        if openaiApiKey.isEmpty {
            modelLoadingMessage = "API key required for remote models"
            self.isModelLoaded = false
            self.isModelReady = false
            return
        }
        
        // Clean up any existing local model
        modelContainer = nil
        
        self.isModelLoaded = true
        self.isModelReady = true
        modelLoadingMessage = "Remote model ready!"
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
        
        guard let config = AIModelConfiguration.getConfiguration(for: selectedModel) else {
            throw MLXLLMError.unsupportedModel
        }
        
        switch config.type {
        case .local:
            if let container = modelContainer {
                // Use MLX model for analysis
                analysis = try await performMLXAnalysis(
                    container: container,
                    text: truncatedText,
                    appName: appName,
                    windowTitle: windowTitle
                )
            } else {
                throw MLXLLMError.modelNotLoaded
            }
            
        case .remote:
            // Use remote API for analysis
            analysis = try await performRemoteAnalysis(
                text: truncatedText,
                appName: appName,
                windowTitle: windowTitle
            )
        }
        
        // Analysis completed - timing calculation removed as it was unused
        
        lastAnalysis = analysis
        analysisHistory[appName] = analysis
        
        // Send notification
        print("📢 Analysis complete: \(analysis.is_valid ? "Focused" : "Distracted") - \(analysis.detected_activity) (\(String(format: "%.0f%%", analysis.confidence * 100)))")
        
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
        You are an AI assistant analyzing user activity to determine if they are focused on their stated goal.
        
        USER'S STATED FOCUS/GOAL: "\(userFocus)"
        
        CURRENT ACTIVITY:
        - Application: \(appName)
        - Window title: \(windowTitle ?? "N/A")
        - Screen content (OCR text): \(text)
        
        INSTRUCTIONS:
        Determine if the current activity is DIRECTLY RELATED to the user's stated focus.
        - Mark as is_valid=true ONLY if the activity clearly contributes to the stated focus
        - Mark as is_valid=false for unrelated activities (entertainment, social media, unrelated browsing, etc.)
        - Be strict: if in doubt, mark as invalid
        
        Example: If focus is "Developing my iOS application":
        - Xcode, Swift documentation, iOS tutorials = VALID (true)
        - Cat images, social media, news, YouTube videos = INVALID (false)
        
        Provide a JSON response with this EXACT structure (no duplicate fields):
        {
            "is_valid": true/false,
            "detected_activity": "what user is doing (3-5 words)",
            "explanation": "brief reason (2-7 words)",
            "confidence": 0.0-1.0
        }
        
        Respond ONLY with valid JSON, no additional text.
        """
        
        // DEBUG: Log MLX analysis request
        print("🧠 MLX Analysis: \(selectedModel) | Focus: \(userFocus) | App: \(appName) | OCR: \(text.count) chars")
        
        // Create a chat session for the analysis
        let session = ChatSession(container)
        
        // Generate response using the LLM
        let generatedText = try await session.respond(to: prompt)
        
        // DEBUG: Log MLX response (first 100 chars)
        let preview = String(generatedText.prefix(100))
        print("  Response: \(preview)\(generatedText.count > 100 ? "..." : "")")
        
        // Parse the JSON response
        guard let jsonData = generatedText.data(using: String.Encoding.utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let isValid = json["is_valid"] as? Bool,
              let detectedActivity = json["detected_activity"] as? String,
              let explanation = json["explanation"] as? String else {
            
            print("  ❌ Failed to parse JSON response")
            // If JSON parsing fails, throw an error instead of using fallback
            throw MLXLLMError.invalidResponse
        }
        
        // DEBUG: Log parsed result
        let confidence = (json["confidence"] as? Double) ?? 0.7
        print("  ✅ Parsed: valid=\(isValid), activity=\(detectedActivity), confidence=\(String(format: "%.2f", confidence))")
        
        // Return the LLM's analysis without any overrides or modifications
        let result = MLXAnalysisResult(
            is_valid: isValid,
            explanation: explanation,
            detected_activity: detectedActivity,
            confidence: confidence,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            analysis_source: "llm"
        )
        
        // DEBUG: Final result
        print("  Final: \(result.is_valid ? "✓ Focused" : "✗ Distracted") - \(result.detected_activity)")
        
        return result
    }
    
    private func performRemoteAnalysis(text: String, appName: String, windowTitle: String?) async throws -> MLXAnalysisResult {
        guard !openaiApiKey.isEmpty else {
            throw MLXLLMError.apiKeyRequired
        }
        
        let prompt = """
        You are an AI assistant analyzing user activity to determine if they are focused on their stated goal.
        
        USER'S STATED FOCUS/GOAL: "\(userFocus)"
        
        CURRENT ACTIVITY:
        - Application: \(appName)
        - Window title: \(windowTitle ?? "N/A")
        - Screen content (OCR text): \(text)
        
        INSTRUCTIONS:
        Determine if the current activity is DIRECTLY RELATED to the user's stated focus.
        - Mark as is_valid=true ONLY if the activity clearly contributes to the stated focus
        - Mark as is_valid=false for unrelated activities (entertainment, social media, unrelated browsing, etc.)
        - Be strict: if in doubt, mark as invalid
        
        Example: If focus is "Developing my iOS application":
        - Xcode, Swift documentation, iOS tutorials = VALID (true)
        - Cat images, social media, news, YouTube videos = INVALID (false)
        
        Provide a JSON response with this EXACT structure (no duplicate fields):
        {
            "is_valid": true/false,
            "detected_activity": "what user is doing (3-5 words)",
            "explanation": "brief reason (2-7 words)",
            "confidence": 0.0-1.0
        }
        
        Respond ONLY with valid JSON, no additional text.
        """
        
        // DEBUG: Log OpenAI request
        print("🤖 OpenAI Request: \(selectedModel) | Focus: \(userFocus) | App: \(appName) | OCR: \(text.count) chars")
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openaiApiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0  // 30 second timeout
        
        // Build request body based on model type
        var requestBody: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        // Add model-specific parameters
        if selectedModel.hasPrefix("gpt-5") {
            // GPT-5 specific parameters
            // Note: GPT-5 only supports default temperature (1), so we don't set it
            requestBody["max_completion_tokens"] = 8000  // Increased to account for reasoning tokens
            requestBody["reasoning_effort"] = "minimal"  // Controls reasoning depth
            requestBody["verbosity"] = "low"            // Keeps responses concise for JSON parsing
            
            // Use structured outputs for guaranteed JSON format
            requestBody["response_format"] = [
                "type": "json_schema",
                "json_schema": [
                    "name": "activity_analysis",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "is_valid": ["type": "boolean"],
                            "detected_activity": ["type": "string"],
                            "explanation": ["type": "string"],
                            "confidence": ["type": "number", "minimum": 0, "maximum": 1]
                        ],
                        "required": ["is_valid", "detected_activity", "explanation", "confidence"]
                    ]
                ]
            ]
        } else {
            // For non-GPT-5 models, use standard parameters
            requestBody["max_tokens"] = 200
            requestBody["temperature"] = 0.1  // Non-GPT-5 models support custom temperature
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // DEBUG: Log key request parameters
            if selectedModel.hasPrefix("gpt-5") {
                print("  Params: reasoning=minimal, verbosity=low, max_tokens=8000")
            } else {
                print("  Params: temperature=0.3, max_tokens=150")
            }
        } catch {
            print("  ❌ Failed to serialize request: \(error.localizedDescription)")
            throw MLXLLMError.networkError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("  ❌ Invalid HTTP response")
                throw MLXLLMError.networkError
            }
            
            // DEBUG: Log response status
            print("  Response: HTTP \(httpResponse.statusCode)")
            
            // Handle different HTTP status codes more specifically
            switch httpResponse.statusCode {
            case 200:
                // Success - logged later with result
                break // Success
            case 401:
                print("  ❌ API key invalid or unauthorized")
                throw MLXLLMError.apiKeyRequired
            case 429:
                print("  ⚠️ Rate limit exceeded")
                throw MLXLLMError.networkError  // Rate limit
            case 500...599:
                print("  ❌ Server error")
                throw MLXLLMError.networkError  // Server error
            default:
                print("  ❌ Unexpected status: \(httpResponse.statusCode)")
                // Try to parse error response for more details
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("OpenAI API Error: \(message)")
                }
                throw MLXLLMError.networkError
            }
            
            // Raw response logged only on error (see error handling above)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("  ❌ Failed to parse response structure")
                throw MLXLLMError.invalidResponse
            }
            
            // Content extracted successfully
            
            // Clean up potential malformed JSON (duplicate keys, etc)
            let cleanedContent = cleanupMalformedJSON(content)
            
            // Parse the JSON response from the AI
            guard let responseData = cleanedContent.data(using: .utf8),
                  let analysisJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let isValid = analysisJson["is_valid"] as? Bool,
                  let detectedActivity = analysisJson["detected_activity"] as? String,
                  let explanation = analysisJson["explanation"] as? String else {
                
                print("  ❌ Failed to parse JSON: \(content.prefix(100))...")
                
                // For OpenAI models, throw error instead of using unreliable fallback
                throw MLXLLMError.invalidResponse
            }
            
            // DEBUG: Log parsed result
            let confidence = (analysisJson["confidence"] as? Double) ?? 0.7
            print("  ✅ Parsed: valid=\(isValid), activity=\(detectedActivity), confidence=\(String(format: "%.2f", confidence))")
            
            var finalIsValid = isValid
            var finalConfidence = (analysisJson["confidence"] as? Double) ?? 0.7
            var finalExplanation = explanation
            
            // Apply lenient "Debugging" focus rule even when JSON parsing succeeds
            let isDebuggingFocus = userFocus.lowercased().contains("debug")
            if isDebuggingFocus && !isValid {
                let hasCodeEvidence = detectCodeEvidence(text: text, appName: appName)
                if hasCodeEvidence {
                    finalIsValid = true
                    finalConfidence = max(finalConfidence, 0.75)
                    finalExplanation = "Coding: \(detectedActivity)"
                }
            }
            
            let finalResult = MLXAnalysisResult(
                is_valid: finalIsValid,
                explanation: finalExplanation,
                detected_activity: detectedActivity,
                confidence: finalConfidence,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                analysis_source: "remote"
            )
            
            // DEBUG: Final result
            print("  Final: \(finalResult.is_valid ? "✓ Focused" : "✗ Distracted") - \(finalResult.detected_activity)")
            
            return finalResult
            
        } catch {
            // More specific error handling for network issues
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    print("OpenAI API request timed out")
                case .notConnectedToInternet:
                    print("No internet connection")
                case .cannotConnectToHost:
                    print("Cannot connect to OpenAI API")
                case .networkConnectionLost:
                    print("Network connection lost during request")
                default:
                    print("URL Error: \(urlError.localizedDescription)")
                }
            } else {
                print("Network error: \(error.localizedDescription)")
            }
            throw MLXLLMError.networkError
        }
    }
    
    private func cleanupMalformedJSON(_ json: String) -> String {
        // Remove duplicate fields by parsing with regex and keeping only first occurrence
        var cleaned = json
        
        // Common malformed patterns from GPT models
        // Pattern: multiple "detected_activity" fields
        if let regex = try? NSRegularExpression(pattern: #"("detected_activity"\s*:\s*"[^"]*")(.*?)("detected_activity"\s*:\s*"[^"]*")"#, options: []) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, 
                                                    options: [], 
                                                    range: NSRange(location: 0, length: cleaned.count), 
                                                    withTemplate: "$1$2")
        }
        
        // Remove trailing commas before closing braces
        cleaned = cleaned.replacingOccurrences(of: ",\\s*}", with: "}", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: ",\\s*]", with: "]", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
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
            return "coding"
        } else if appLower.contains("safari") || appLower.contains("chrome") {
            return "browsing"
        } else if appLower.contains("slack") || appLower.contains("messages") {
            return "messaging"
        } else if appLower.contains("pages") || appLower.contains("word") {
            return "writing"
        } else {
            return "working"
        }
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
        guard AIModelConfiguration.getConfiguration(for: modelID) != nil else {
            return // Invalid model ID
        }
        
        selectedModel = modelID
        isModelLoaded = false
        isModelReady = false
        
        // Clean up existing model
        modelContainer = nil
        
        // Load new model
        await loadModel()
    }
    
    var currentModelConfig: AIModelConfiguration? {
        return AIModelConfiguration.getConfiguration(for: selectedModel)
    }
    
    var isRemoteModel: Bool {
        return currentModelConfig?.type == .remote
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
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI Ready")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    if let config = mlxManager.currentModelConfig {
                        Text(config.displayName)
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
            }
        }
    }
}


