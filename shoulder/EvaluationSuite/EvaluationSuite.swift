//
//  EvaluationSuite.swift
//  shoulder
//
//  Created by Claude Code on 9/3/25.
//

import Foundation
import SwiftUI

enum EvaluationError: Error {
    case invalidGroundTruth
    case modelNotAvailable
    case insufficientData
    case evaluationTimeout
    case fileSystemError
}

struct EvaluationResult {
    let modelId: String
    let metrics: EvaluationMetrics
    let evaluationDate: Date
    let sampleCount: Int
    let evaluationTime: TimeInterval
    let detailedResults: [SampleResult]
}

struct SampleResult {
    let groundTruth: GroundTruthSample
    let prediction: MLXAnalysisResult
    let isCorrect: Bool
    let confidenceError: Double // |predicted_confidence - actual_accuracy|
}

struct EvaluationMetrics {
    // Binary Classification Metrics
    let accuracy: Double
    let precision: Double
    let recall: Double
    let f1Score: Double
    let specificity: Double
    
    // Confidence Analysis Metrics
    let calibrationError: Double
    let aucRoc: Double
    let confidenceAccuracyCorrelation: Double
    
    // Performance Metrics
    let averageResponseTime: Double
    let failureRate: Double
    
    // Content-Specific Metrics
    let focusAreaPerformance: [String: Double] // Per-category accuracy
    let appContextAccuracy: [String: Double] // Per-app accuracy
    let ocrQualityImpact: Double // OCR confidence vs classification accuracy correlation
    let temporalConsistency: Double // Agreement rate for consecutive screenshots
    
    init(
        accuracy: Double = 0,
        precision: Double = 0,
        recall: Double = 0,
        f1Score: Double = 0,
        specificity: Double = 0,
        calibrationError: Double = 0,
        aucRoc: Double = 0,
        confidenceAccuracyCorrelation: Double = 0,
        averageResponseTime: Double = 0,
        failureRate: Double = 0,
        focusAreaPerformance: [String: Double] = [:],
        appContextAccuracy: [String: Double] = [:],
        ocrQualityImpact: Double = 0,
        temporalConsistency: Double = 0
    ) {
        self.accuracy = accuracy
        self.precision = precision
        self.recall = recall
        self.f1Score = f1Score
        self.specificity = specificity
        self.calibrationError = calibrationError
        self.aucRoc = aucRoc
        self.confidenceAccuracyCorrelation = confidenceAccuracyCorrelation
        self.averageResponseTime = averageResponseTime
        self.failureRate = failureRate
        self.focusAreaPerformance = focusAreaPerformance
        self.appContextAccuracy = appContextAccuracy
        self.ocrQualityImpact = ocrQualityImpact
        self.temporalConsistency = temporalConsistency
    }
}

@MainActor
class EvaluationSuite: ObservableObject {
    @Published var isEvaluating = false
    @Published var evaluationProgress: Double = 0
    @Published var currentStatus = "Ready"
    @Published var lastEvaluationResult: EvaluationResult?
    @Published var evaluationHistory: [EvaluationResult] = []
    
    private let groundTruthDataset: GroundTruthDataset
    private let metricsCalculator: MetricsCalculator
    private let reportGenerator: ReportGenerator
    private let mlxManager: MLXLLMManager
    
    init(mlxManager: MLXLLMManager) {
        self.mlxManager = mlxManager
        self.groundTruthDataset = GroundTruthDataset()
        self.metricsCalculator = MetricsCalculator()
        self.reportGenerator = ReportGenerator()
        
        loadEvaluationHistory()
    }
    
    func evaluateModel(modelId: String? = nil, maxSamples: Int = 100) async throws -> EvaluationResult {
        guard !isEvaluating else {
            throw EvaluationError.evaluationTimeout
        }
        
        isEvaluating = true
        evaluationProgress = 0
        currentStatus = "Loading ground truth data..."
        
        defer {
            isEvaluating = false
            currentStatus = "Ready"
        }
        
        do {
            // Load ground truth samples
            let samples = try await groundTruthDataset.loadSamples(maxCount: maxSamples)
            guard !samples.isEmpty else {
                throw EvaluationError.insufficientData
            }
            
            currentStatus = "Evaluating \(samples.count) samples..."
            
            // Use provided model or current model
            let targetModel = modelId ?? mlxManager.selectedModel
            let originalModel = mlxManager.selectedModel
            
            // Switch to target model if needed
            if targetModel != originalModel {
                currentStatus = "Switching to \(targetModel)..."
                await mlxManager.switchModel(to: targetModel)
                
                // Wait for model to be ready
                var attempts = 0
                while !mlxManager.isModelReady && attempts < 30 {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    attempts += 1
                }
                
                if !mlxManager.isModelReady {
                    throw EvaluationError.modelNotAvailable
                }
            }
            
            // Run evaluation
            let startTime = Date()
            var results: [SampleResult] = []
            var responseTimes: [Double] = []
            var failures = 0
            
            for (index, sample) in samples.enumerated() {
                evaluationProgress = Double(index) / Double(samples.count)
                currentStatus = "Evaluating sample \(index + 1)/\(samples.count)..."
                
                let sampleStartTime = Date()
                
                do {
                    let prediction = try await mlxManager.analyzeScreenshot(
                        ocrText: sample.ocrText,
                        appName: sample.appName,
                        windowTitle: sample.windowTitle
                    )
                    
                    let responseTime = Date().timeIntervalSince(sampleStartTime)
                    responseTimes.append(responseTime)
                    
                    let isCorrect = prediction.is_valid == sample.isValid
                    let confidenceError = abs(prediction.confidence - (isCorrect ? 1.0 : 0.0))
                    
                    let result = SampleResult(
                        groundTruth: sample,
                        prediction: prediction,
                        isCorrect: isCorrect,
                        confidenceError: confidenceError
                    )
                    
                    results.append(result)
                    
                } catch {
                    failures += 1
                    print("Evaluation error for sample \(index): \(error)")
                }
            }
            
            let evaluationTime = Date().timeIntervalSince(startTime)
            evaluationProgress = 1.0
            currentStatus = "Calculating metrics..."
            
            // Calculate metrics
            let metrics = metricsCalculator.calculateMetrics(from: results, responseTimes: responseTimes, failures: failures)
            
            // Create final result
            let evaluationResult = EvaluationResult(
                modelId: targetModel,
                metrics: metrics,
                evaluationDate: Date(),
                sampleCount: results.count,
                evaluationTime: evaluationTime,
                detailedResults: results
            )
            
            // Switch back to original model if needed
            if targetModel != originalModel {
                await mlxManager.switchModel(to: originalModel)
            }
            
            // Store results
            lastEvaluationResult = evaluationResult
            evaluationHistory.append(evaluationResult)
            saveEvaluationHistory()
            
            // Generate report
            currentStatus = "Generating report..."
            try await reportGenerator.generateReport(for: evaluationResult)
            
            return evaluationResult
            
        } catch {
            currentStatus = "Evaluation failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func evaluateAllModels(maxSamples: Int = 100) async throws -> [EvaluationResult] {
        var results: [EvaluationResult] = []
        
        for modelConfig in AIModelConfiguration.availableModels {
            do {
                let result = try await evaluateModel(modelId: modelConfig.id, maxSamples: maxSamples)
                results.append(result)
            } catch {
                print("Failed to evaluate model \(modelConfig.id): \(error)")
            }
        }
        
        return results
    }
    
    func compareModels(_ results: [EvaluationResult]) -> ModelComparisonReport {
        return reportGenerator.generateComparisonReport(results)
    }
    
    func generateComparisonReport(_ results: [EvaluationResult]) -> ModelComparisonReport {
        return reportGenerator.generateComparisonReport(results)
    }
    
    private func loadEvaluationHistory() {
        // Load saved evaluation results from file system
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyURL = documentsPath.appendingPathComponent("evaluation_history.json")
        
        do {
            let data = try Data(contentsOf: historyURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            evaluationHistory = try decoder.decode([EvaluationResult].self, from: data)
        } catch {
            // File doesn't exist or is corrupted, start fresh
            evaluationHistory = []
        }
    }
    
    private func saveEvaluationHistory() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyURL = documentsPath.appendingPathComponent("evaluation_history.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(evaluationHistory)
            try data.write(to: historyURL)
        } catch {
            print("Failed to save evaluation history: \(error)")
        }
    }
}

// MARK: - Codable Extensions

extension EvaluationResult: Codable {}
extension SampleResult: Codable {}
extension EvaluationMetrics: Codable {}