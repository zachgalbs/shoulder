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

struct EnhancedAnalysisResult: Codable {
    let student_justification: String
    let student_confidence: Double
    let teacher_verdict: Bool
    let teacher_reasoning: String
    let teacher_confidence: Double
    let final_classification: Bool
    let detected_activity: String
    let timestamp: String
    let analysis_source: String
    
    // Convert to legacy format for backward compatibility
    func toLegacyResult() -> MLXAnalysisResult {
        return MLXAnalysisResult(
            is_valid: final_classification,
            explanation: teacher_reasoning,
            detected_activity: detected_activity,
            confidence: teacher_confidence,
            timestamp: timestamp,
            analysis_source: analysis_source
        )
    }
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
    
    // Configuration constants
    private static let analysisBasePath = "src/shoulder/analyses"
    
    // Common prompt generation methods
    private func generateJustificationPrompt(text: String, appName: String, windowTitle: String?) -> String {
        return """
        You are a student focusing on: "\(userFocus)"
        
        Your teacher sees this activity on your screen:
        - Application: \(appName)
        - Window title: \(windowTitle ?? "N/A")
        - Screen content: \(text)
        
        Write a compelling justification for why this activity supports your focus goal. Be creative and persuasive - you want to convince your teacher this is legitimate work toward your goal.
        
        Provide a JSON response with this EXACT structure:
        {
            "justification": "your persuasive explanation (1-2 sentences)",
            "confidence": 0.0-1.0
        }
        
        Respond ONLY with valid JSON, no additional text.
        """
    }
    
    private func generateJudgmentPrompt(text: String, appName: String, windowTitle: String?, justification: String) -> String {
        return """
        You are a teacher with students who must stay focused on their goals.
        
        STUDENT'S GOAL: "\(userFocus)"
        
        STUDENT'S SCREEN ACTIVITY:
        - Application: \(appName)
        - Window title: \(windowTitle ?? "N/A")
        - Screen content: \(text)
        
        STUDENT'S JUSTIFICATION: "\(justification)"
        
        As a teacher, evaluate whether this student is truly on task or trying to deceive you. Consider:
        - Does the screen content actually support their goal?
        - Is their justification reasonable or just creative excuses?
        - Are they genuinely productive or just trying to get away with something?
        
        Be a fair but discerning teacher. Students can be clever with justifications, but you can see through weak excuses.
        
        Provide a JSON response with this EXACT structure:
        {
            "verdict": true/false,
            "reasoning": "your teaching assessment (1-2 sentences)",
            "confidence": 0.0-1.0
        }
        
        Respond ONLY with valid JSON, no additional text.
        """
    }
    
    private func parseJustificationResponse(_ response: String) throws -> (String, Double) {
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let justification = json["justification"] as? String else {
            throw MLXLLMError.invalidResponse
        }
        
        let confidence = (json["confidence"] as? Double) ?? 0.7
        return (justification, confidence)
    }
    
    private func parseJudgmentResponse(_ response: String) throws -> (Bool, String, Double) {
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let verdict = json["verdict"] as? Bool,
              let reasoning = json["reasoning"] as? String else {
            throw MLXLLMError.invalidResponse
        }
        
        let confidence = (json["confidence"] as? Double) ?? 0.7
        return (verdict, reasoning, confidence)
    }
    
    private func performRemoteAPICall(prompt: String, schemaName: String, properties: [String: [String: Any]], required: [String]) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openaiApiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        var requestBody: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        if selectedModel.hasPrefix("gpt-5") {
            requestBody["max_completion_tokens"] = 8000
            requestBody["reasoning_effort"] = "minimal"
            requestBody["verbosity"] = "low"
            
            requestBody["response_format"] = [
                "type": "json_schema",
                "json_schema": [
                    "name": schemaName,
                    "schema": [
                        "type": "object",
                        "properties": properties,
                        "required": required
                    ]
                ]
            ]
        } else {
            requestBody["max_tokens"] = 200
            requestBody["temperature"] = 0.1
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MLXLLMError.networkError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw MLXLLMError.invalidResponse
        }
        
        return content
    }
    
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
        // Use enhanced dual-LLM analysis and convert to legacy format for backward compatibility
        let enhancedAnalysis = try await analyzeScreenshotEnhanced(ocrText: ocrText, appName: appName, windowTitle: windowTitle)
        return enhancedAnalysis.toLegacyResult()
    }
    
    func analyzeScreenshotEnhanced(ocrText: String, appName: String, windowTitle: String?) async throws -> EnhancedAnalysisResult {
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
        
        print("🎭 Enhanced Dual-LLM Analysis Starting: Student → Teacher")
        
        let enhancedAnalysis: EnhancedAnalysisResult
        
        guard let config = AIModelConfiguration.getConfiguration(for: selectedModel) else {
            throw MLXLLMError.unsupportedModel
        }
        
        switch config.type {
        case .local:
            if let container = modelContainer {
                // Step 1: Student justifies the activity
                let (studentJustification, studentConfidence) = try await performJustificationAnalysisMLX(
                    container: container,
                    text: truncatedText,
                    appName: appName,
                    windowTitle: windowTitle
                )
                
                // Step 2: Teacher judges the justification
                let (teacherVerdict, teacherReasoning, teacherConfidence) = try await performJudgmentAnalysisMLX(
                    container: container,
                    text: truncatedText,
                    appName: appName,
                    windowTitle: windowTitle,
                    justification: studentJustification
                )
                
                enhancedAnalysis = EnhancedAnalysisResult(
                    student_justification: studentJustification,
                    student_confidence: studentConfidence,
                    teacher_verdict: teacherVerdict,
                    teacher_reasoning: teacherReasoning,
                    teacher_confidence: teacherConfidence,
                    final_classification: teacherVerdict,
                    detected_activity: detectActivity(text: truncatedText, appName: appName),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    analysis_source: "enhanced_llm"
                )
            } else {
                throw MLXLLMError.modelNotLoaded
            }
            
        case .remote:
            // Step 1: Student justifies the activity
            let (studentJustification, studentConfidence) = try await performJustificationAnalysisRemote(
                text: truncatedText,
                appName: appName,
                windowTitle: windowTitle
            )
            
            // Step 2: Teacher judges the justification
            let (teacherVerdict, teacherReasoning, teacherConfidence) = try await performJudgmentAnalysisRemote(
                text: truncatedText,
                appName: appName,
                windowTitle: windowTitle,
                justification: studentJustification
            )
            
            enhancedAnalysis = EnhancedAnalysisResult(
                student_justification: studentJustification,
                student_confidence: studentConfidence,
                teacher_verdict: teacherVerdict,
                teacher_reasoning: teacherReasoning,
                teacher_confidence: teacherConfidence,
                final_classification: teacherVerdict,
                detected_activity: detectActivity(text: truncatedText, appName: appName),
                timestamp: ISO8601DateFormatter().string(from: Date()),
                analysis_source: "enhanced_remote"
            )
        }
        
        // Update state with legacy format for existing UI compatibility
        let legacyResult = enhancedAnalysis.toLegacyResult()
        lastAnalysis = legacyResult
        analysisHistory[appName] = legacyResult
        
        // Send notification
        print("📢 Enhanced Analysis Complete: \(enhancedAnalysis.final_classification ? "FOCUSED" : "DISTRACTED")")
        print("   Student: \(enhancedAnalysis.student_justification)")
        print("   Teacher: \(enhancedAnalysis.teacher_reasoning)")
        
        // Send notification for blocking manager to handle (using legacy format)
        NotificationCenter.default.post(
            name: .mlxAnalysisCompleted,
            object: nil,
            userInfo: ["analysis": legacyResult, "appName": appName]
        )
        
        // Save both enhanced and legacy formats
        await saveEnhancedAnalysisResult(enhancedAnalysis, appName: appName)
        await saveAnalysisResult(legacyResult, appName: appName)
        
        return enhancedAnalysis
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
        Determine if the current activity is PRODUCTIVE toward the user's stated focus.
        - Mark is_valid=true when the activity directly advances the goal OR reasonably supports it (research, documentation, tooling, planning, communication about the task, etc.)
        - Mark is_valid=false only for clearly unrelated or distracting content (entertainment, personal social feeds, random browsing with no connection to the goal, etc.)
        - If the evidence is ambiguous or mixed, lean toward is_valid=true and explain why it still supports the work.
        
        Examples for the focus "Developing my iOS application":
        - Xcode, Swift documentation, design discussions, Apple Developer forums = VALID (true)
        - Cat images, unrelated news, entertainment videos = INVALID (false)
        
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
    
    private func performJustificationAnalysisMLX(container: ModelContainer, text: String, appName: String, windowTitle: String?) async throws -> (String, Double) {
        let prompt = generateJustificationPrompt(text: text, appName: appName, windowTitle: windowTitle)
        
        print("🎓 Student MLX Justification: \(selectedModel) | Focus: \(userFocus) | App: \(appName)")
        
        let session = ChatSession(container)
        let generatedText = try await session.respond(to: prompt)
        
        do {
            let (justification, confidence) = try parseJustificationResponse(generatedText)
            print("  ✅ Student says: \(justification) (confidence: \(String(format: "%.2f", confidence)))")
            return (justification, confidence)
        } catch {
            print("  ❌ Failed to parse student justification JSON")
            throw MLXLLMError.invalidResponse
        }
    }
    
    private func performJustificationAnalysisRemote(text: String, appName: String, windowTitle: String?) async throws -> (String, Double) {
        guard !openaiApiKey.isEmpty else {
            throw MLXLLMError.apiKeyRequired
        }
        
        let prompt = generateJustificationPrompt(text: text, appName: appName, windowTitle: windowTitle)
        
        print("🎓 Student Remote Justification: \(selectedModel) | Focus: \(userFocus) | App: \(appName)")
        
        let content = try await performRemoteAPICall(prompt: prompt, schemaName: "student_justification", properties: [
            "justification": ["type": "string"],
            "confidence": ["type": "number", "minimum": 0, "maximum": 1]
        ], required: ["justification", "confidence"])
        
        let cleanedContent = cleanupMalformedJSON(content)
        
        do {
            let (justification, confidence) = try parseJustificationResponse(cleanedContent)
            print("  ✅ Student says: \(justification) (confidence: \(String(format: "%.2f", confidence)))")
            return (justification, confidence)
        } catch {
            print("  ❌ Failed to parse student justification JSON: \(content.prefix(100))...")
            throw MLXLLMError.invalidResponse
        }
    }
    
    private func performJudgmentAnalysisMLX(container: ModelContainer, text: String, appName: String, windowTitle: String?, justification: String) async throws -> (Bool, String, Double) {
        let prompt = generateJudgmentPrompt(text: text, appName: appName, windowTitle: windowTitle, justification: justification)
        
        print("👩‍🏫 Teacher MLX Judgment: \(selectedModel) | Focus: \(userFocus)")
        
        let session = ChatSession(container)
        let generatedText = try await session.respond(to: prompt)
        
        do {
            let (verdict, reasoning, confidence) = try parseJudgmentResponse(generatedText)
            print("  ✅ Teacher says: \(verdict ? "FOCUSED" : "DISTRACTED") - \(reasoning) (confidence: \(String(format: "%.2f", confidence)))")
            return (verdict, reasoning, confidence)
        } catch {
            print("  ❌ Failed to parse teacher judgment JSON")
            throw MLXLLMError.invalidResponse
        }
    }
    
    private func performJudgmentAnalysisRemote(text: String, appName: String, windowTitle: String?, justification: String) async throws -> (Bool, String, Double) {
        guard !openaiApiKey.isEmpty else {
            throw MLXLLMError.apiKeyRequired
        }
        
        let prompt = generateJudgmentPrompt(text: text, appName: appName, windowTitle: windowTitle, justification: justification)
        
        print("👩‍🏫 Teacher Remote Judgment: \(selectedModel) | Focus: \(userFocus)")
        
        let content = try await performRemoteAPICall(prompt: prompt, schemaName: "teacher_judgment", properties: [
            "verdict": ["type": "boolean"],
            "reasoning": ["type": "string"],
            "confidence": ["type": "number", "minimum": 0, "maximum": 1]
        ], required: ["verdict", "reasoning", "confidence"])
        
        let cleanedContent = cleanupMalformedJSON(content)
        
        do {
            let (verdict, reasoning, confidence) = try parseJudgmentResponse(cleanedContent)
            print("  ✅ Teacher says: \(verdict ? "FOCUSED" : "DISTRACTED") - \(reasoning) (confidence: \(String(format: "%.2f", confidence)))")
            return (verdict, reasoning, confidence)
        } catch {
            print("  ❌ Failed to parse teacher judgment JSON: \(content.prefix(100))...")
            throw MLXLLMError.invalidResponse
        }
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
        Determine if the current activity is PRODUCTIVE toward the user's stated focus.
        - Mark is_valid=true when the activity directly advances the goal OR reasonably supports it (research, documentation, tooling, planning, communication about the task, etc.)
        - Mark is_valid=false only for clearly unrelated or distracting content (entertainment, personal social feeds, random browsing with no connection to the goal, etc.)
        - If the evidence is ambiguous or mixed, lean toward is_valid=true and explain why it still supports the work.
        
        Examples for the focus "Developing my iOS application":
        - Xcode, Swift documentation, design discussions, Apple Developer forums = VALID (true)
        - Cat images, unrelated news, entertainment videos = INVALID (false)
        
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
        let analysisDir = homeDir.appendingPathComponent("\(Self.analysisBasePath)/\(dateString)")
        let analysisFile = analysisDir.appendingPathComponent("analysis-\(timeString).json")
        
        do {
            try FileManager.default.createDirectory(at: analysisDir, withIntermediateDirectories: true, attributes: nil)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(result)
            
            try data.write(to: analysisFile)
        } catch {
            print("❌ Failed to save analysis result: \(error.localizedDescription)")
        }
    }
    
    private func saveEnhancedAnalysisResult(_ result: EnhancedAnalysisResult, appName: String) async {
        let dateString = DateFormatters.fileDate.string(from: Date())
        let timeString = DateFormatters.fileTime.string(from: Date())
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let analysisDir = homeDir.appendingPathComponent("\(Self.analysisBasePath)/\(dateString)")
        let enhancedFile = analysisDir.appendingPathComponent("enhanced-analysis-\(timeString).json")
        
        do {
            try FileManager.default.createDirectory(at: analysisDir, withIntermediateDirectories: true, attributes: nil)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(result)
            
            try data.write(to: enhancedFile)
        } catch {
            print("❌ Failed to save enhanced analysis result: \(error.localizedDescription)")
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

