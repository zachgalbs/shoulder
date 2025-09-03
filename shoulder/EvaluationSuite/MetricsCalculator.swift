//
//  MetricsCalculator.swift
//  shoulder
//
//  Created by Claude Code on 9/3/25.
//

import Foundation

struct ConfusionMatrix {
    let truePositives: Int
    let falsePositives: Int
    let trueNegatives: Int
    let falseNegatives: Int
    
    var total: Int {
        return truePositives + falsePositives + trueNegatives + falseNegatives
    }
    
    var accuracy: Double {
        guard total > 0 else { return 0 }
        return Double(truePositives + trueNegatives) / Double(total)
    }
    
    var precision: Double {
        let denominator = truePositives + falsePositives
        guard denominator > 0 else { return 0 }
        return Double(truePositives) / Double(denominator)
    }
    
    var recall: Double {
        let denominator = truePositives + falseNegatives
        guard denominator > 0 else { return 0 }
        return Double(truePositives) / Double(denominator)
    }
    
    var specificity: Double {
        let denominator = trueNegatives + falsePositives
        guard denominator > 0 else { return 0 }
        return Double(trueNegatives) / Double(denominator)
    }
    
    var f1Score: Double {
        let prec = precision
        let rec = recall
        guard prec + rec > 0 else { return 0 }
        return 2 * (prec * rec) / (prec + rec)
    }
}

class MetricsCalculator {
    
    func calculateMetrics(from results: [SampleResult], responseTimes: [Double], failures: Int) -> EvaluationMetrics {
        guard !results.isEmpty else {
            return EvaluationMetrics()
        }
        
        // Basic confusion matrix
        let confusionMatrix = buildConfusionMatrix(from: results)
        
        // Confidence analysis
        let calibrationError = calculateCalibrationError(from: results)
        let aucRoc = calculateAUCROC(from: results)
        let confidenceCorrelation = calculateConfidenceAccuracyCorrelation(from: results)
        
        // Performance metrics
        let avgResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
        let failureRate = Double(failures) / Double(results.count + failures)
        
        // Content-specific metrics
        let focusAreaPerformance = calculateFocusAreaPerformance(from: results)
        let appContextAccuracy = calculateAppContextAccuracy(from: results)
        let ocrQualityImpact = calculateOCRQualityImpact(from: results)
        let temporalConsistency = calculateTemporalConsistency(from: results)
        
        return EvaluationMetrics(
            accuracy: confusionMatrix.accuracy,
            precision: confusionMatrix.precision,
            recall: confusionMatrix.recall,
            f1Score: confusionMatrix.f1Score,
            specificity: confusionMatrix.specificity,
            calibrationError: calibrationError,
            aucRoc: aucRoc,
            confidenceAccuracyCorrelation: confidenceCorrelation,
            averageResponseTime: avgResponseTime,
            failureRate: failureRate,
            focusAreaPerformance: focusAreaPerformance,
            appContextAccuracy: appContextAccuracy,
            ocrQualityImpact: ocrQualityImpact,
            temporalConsistency: temporalConsistency
        )
    }
    
    private func buildConfusionMatrix(from results: [SampleResult]) -> ConfusionMatrix {
        var truePositives = 0
        var falsePositives = 0
        var trueNegatives = 0
        var falseNegatives = 0
        
        for result in results {
            let predicted = result.prediction.is_valid
            let actual = result.groundTruth.isValid
            
            switch (predicted, actual) {
            case (true, true):
                truePositives += 1
            case (true, false):
                falsePositives += 1
            case (false, false):
                trueNegatives += 1
            case (false, true):
                falseNegatives += 1
            }
        }
        
        return ConfusionMatrix(
            truePositives: truePositives,
            falsePositives: falsePositives,
            trueNegatives: trueNegatives,
            falseNegatives: falseNegatives
        )
    }
    
    private func calculateCalibrationError(from results: [SampleResult]) -> Double {
        // Bin predictions by confidence and calculate calibration error
        let binCount = 10
        var bins: [[SampleResult]] = Array(repeating: [], count: binCount)
        
        for result in results {
            let binIndex = min(Int(result.prediction.confidence * Double(binCount)), binCount - 1)
            bins[binIndex].append(result)
        }
        
        var totalError = 0.0
        var totalSamples = 0
        
        for (binIndex, binResults) in bins.enumerated() {
            guard !binResults.isEmpty else { continue }
            
            let binMidpoint = (Double(binIndex) + 0.5) / Double(binCount)
            let binAccuracy = Double(binResults.filter { $0.isCorrect }.count) / Double(binResults.count)
            let binSize = binResults.count
            
            totalError += Double(binSize) * abs(binMidpoint - binAccuracy)
            totalSamples += binSize
        }
        
        return totalSamples > 0 ? totalError / Double(totalSamples) : 0.0
    }
    
    private func calculateAUCROC(from results: [SampleResult]) -> Double {
        // Sort by confidence (descending)
        let sortedResults = results.sorted { $0.prediction.confidence > $1.prediction.confidence }
        
        var truePositives = 0
        var falsePositives = 0
        let totalPositives = results.filter { $0.groundTruth.isValid }.count
        let totalNegatives = results.count - totalPositives
        
        guard totalPositives > 0 && totalNegatives > 0 else { return 0.5 }
        
        var auc = 0.0
        var prevFPR = 0.0
        
        for result in sortedResults {
            if result.groundTruth.isValid {
                truePositives += 1
            } else {
                falsePositives += 1
            }
            
            let tpr = Double(truePositives) / Double(totalPositives)
            let fpr = Double(falsePositives) / Double(totalNegatives)
            
            // Trapezoidal rule
            auc += (fpr - prevFPR) * tpr
            prevFPR = fpr
        }
        
        return auc
    }
    
    private func calculateConfidenceAccuracyCorrelation(from results: [SampleResult]) -> Double {
        guard results.count > 1 else { return 0.0 }
        
        let confidences = results.map { $0.prediction.confidence }
        let accuracies = results.map { $0.isCorrect ? 1.0 : 0.0 }
        
        return pearsonCorrelation(confidences, accuracies)
    }
    
    private func calculateFocusAreaPerformance(from results: [SampleResult]) -> [String: Double] {
        let groupedByFocusArea = Dictionary(grouping: results) { $0.groundTruth.focusArea }
        
        return groupedByFocusArea.mapValues { areaResults in
            let correct = areaResults.filter { $0.isCorrect }.count
            return Double(correct) / Double(areaResults.count)
        }
    }
    
    private func calculateAppContextAccuracy(from results: [SampleResult]) -> [String: Double] {
        let groupedByApp = Dictionary(grouping: results) { $0.groundTruth.appName }
        
        return groupedByApp.mapValues { appResults in
            let correct = appResults.filter { $0.isCorrect }.count
            return Double(correct) / Double(appResults.count)
        }
    }
    
    private func calculateOCRQualityImpact(from results: [SampleResult]) -> Double {
        let resultsWithOCR = results.filter { $0.groundTruth.ocrConfidence != nil }
        guard resultsWithOCR.count > 1 else { return 0.0 }
        
        let ocrConfidences = resultsWithOCR.compactMap { $0.groundTruth.ocrConfidence }
        let classificationAccuracies = resultsWithOCR.map { $0.isCorrect ? 1.0 : 0.0 }
        
        return pearsonCorrelation(ocrConfidences, classificationAccuracies)
    }
    
    private func calculateTemporalConsistency(from results: [SampleResult]) -> Double {
        // Group by app and sort by timestamp to find consecutive samples
        let groupedByApp = Dictionary(grouping: results) { $0.groundTruth.appName }
        
        var totalConsistencyChecks = 0
        var consistentPairs = 0
        
        for (_, appResults) in groupedByApp {
            let sortedResults = appResults.sorted { $0.groundTruth.annotationDate < $1.groundTruth.annotationDate }
            
            for i in 0..<(sortedResults.count - 1) {
                let current = sortedResults[i]
                let next = sortedResults[i + 1]
                
                // Consider consecutive if within 5 minutes
                let timeDiff = next.groundTruth.annotationDate.timeIntervalSince(current.groundTruth.annotationDate)
                if timeDiff <= 300 { // 5 minutes
                    totalConsistencyChecks += 1
                    if current.prediction.is_valid == next.prediction.is_valid {
                        consistentPairs += 1
                    }
                }
            }
        }
        
        return totalConsistencyChecks > 0 ? Double(consistentPairs) / Double(totalConsistencyChecks) : 0.0
    }
    
    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count && x.count > 1 else { return 0.0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        
        return denominator > 0 ? numerator / denominator : 0.0
    }
    
    func generatePerformanceSummary(metrics: EvaluationMetrics, modelId: String) -> String {
        var summary = "📊 **\(modelId) Performance Summary**\n\n"
        
        // Classification Performance
        summary += "**Classification Metrics:**\n"
        summary += "- Accuracy: \(String(format: "%.3f", metrics.accuracy)) (\(String(format: "%.1f%%", metrics.accuracy * 100)))\n"
        summary += "- Precision: \(String(format: "%.3f", metrics.precision))\n"
        summary += "- Recall: \(String(format: "%.3f", metrics.recall))\n"
        summary += "- F1-Score: \(String(format: "%.3f", metrics.f1Score))\n"
        summary += "- Specificity: \(String(format: "%.3f", metrics.specificity))\n\n"
        
        // Confidence Analysis
        summary += "**Confidence Analysis:**\n"
        summary += "- Calibration Error: \(String(format: "%.3f", metrics.calibrationError))\n"
        summary += "- AUC-ROC: \(String(format: "%.3f", metrics.aucRoc))\n"
        summary += "- Confidence-Accuracy Correlation: \(String(format: "%.3f", metrics.confidenceAccuracyCorrelation))\n\n"
        
        // Performance Metrics
        summary += "**Performance:**\n"
        summary += "- Average Response Time: \(String(format: "%.2f", metrics.averageResponseTime))s\n"
        summary += "- Failure Rate: \(String(format: "%.1f%%", metrics.failureRate * 100))\n\n"
        
        // Performance Tier
        let tier = determinePerformanceTier(f1Score: metrics.f1Score)
        summary += "**Performance Tier:** \(tier)\n\n"
        
        return summary
    }
    
    private func determinePerformanceTier(f1Score: Double) -> String {
        if f1Score >= 0.85 {
            return "🟢 Production-Ready"
        } else if f1Score >= 0.75 {
            return "🟡 Acceptable"
        } else {
            return "🔴 Needs-Improvement"
        }
    }
}