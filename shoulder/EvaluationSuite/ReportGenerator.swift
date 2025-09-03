//
//  ReportGenerator.swift
//  shoulder
//
//  Created by Claude Code on 9/3/25.
//

import Foundation

struct ModelComparisonReport {
    let results: [EvaluationResult]
    let bestModel: String?
    let recommendations: [String]
    let comparisonTable: String
    
    init(results: [EvaluationResult]) {
        self.results = results
        self.bestModel = results.max(by: { $0.metrics.f1Score < $1.metrics.f1Score })?.modelId
        self.recommendations = ModelComparisonReport.generateRecommendations(from: results)
        self.comparisonTable = ModelComparisonReport.generateComparisonTable(from: results)
    }
    
    private static func generateRecommendations(from results: [EvaluationResult]) -> [String] {
        guard !results.isEmpty else { return [] }
        
        var recommendations: [String] = []
        
        // Find best performing model
        if let best = results.max(by: { $0.metrics.f1Score < $1.metrics.f1Score }) {
            recommendations.append("🏆 **Best Overall:** \(best.modelId) (F1: \(String(format: "%.3f", best.metrics.f1Score)))")
        }
        
        // Find fastest model
        if let fastest = results.min(by: { $0.metrics.averageResponseTime < $1.metrics.averageResponseTime }) {
            recommendations.append("⚡ **Fastest:** \(fastest.modelId) (\(String(format: "%.2f", fastest.metrics.averageResponseTime))s avg)")
        }
        
        // Find most calibrated model
        if let mostCalibrated = results.min(by: { $0.metrics.calibrationError < $1.metrics.calibrationError }) {
            recommendations.append("🎯 **Best Calibrated:** \(mostCalibrated.modelId) (Error: \(String(format: "%.3f", mostCalibrated.calibrationError)))")
        }
        
        // Performance tier analysis
        let productionReady = results.filter { $0.metrics.f1Score >= 0.85 }
        let acceptable = results.filter { $0.metrics.f1Score >= 0.75 && $0.metrics.f1Score < 0.85 }
        let needsImprovement = results.filter { $0.metrics.f1Score < 0.75 }
        
        if !productionReady.isEmpty {
            recommendations.append("✅ **Production Ready:** \(productionReady.map { $0.modelId }.joined(separator: ", "))")
        }
        
        if !acceptable.isEmpty {
            recommendations.append("⚠️ **Acceptable:** \(acceptable.map { $0.modelId }.joined(separator: ", "))")
        }
        
        if !needsImprovement.isEmpty {
            recommendations.append("❌ **Needs Improvement:** \(needsImprovement.map { $0.modelId }.joined(separator: ", "))")
        }
        
        // Cost-performance analysis for remote models
        let remoteResults = results.filter { $0.modelId.hasPrefix("gpt") }
        if remoteResults.count > 1 {
            // Assuming cost tiers: gpt-5 > gpt-5-mini > gpt-5-nano
            let costEffective = remoteResults.max { a, b in
                let aCostTier = getCostTier(a.modelId)
                let bCostTier = getCostTier(b.modelId)
                let aScore = a.metrics.f1Score / Double(aCostTier)
                let bScore = b.metrics.f1Score / Double(bCostTier)
                return aScore < bScore
            }
            
            if let costEffective = costEffective {
                recommendations.append("💰 **Most Cost-Effective:** \(costEffective.modelId)")
            }
        }
        
        return recommendations
    }
    
    private static func getCostTier(_ modelId: String) -> Int {
        if modelId.contains("gpt-5-nano") { return 1 }
        if modelId.contains("gpt-5-mini") { return 2 }
        if modelId.contains("gpt-5") { return 3 }
        return 1 // Local models are essentially free
    }
    
    private static func generateComparisonTable(from results: [EvaluationResult]) -> String {
        guard !results.isEmpty else { return "No results available" }
        
        var table = "| Model | F1 | Accuracy | Precision | Recall | Calibration | Avg Time | Tier |\n"
        table += "|-------|----|---------|-----------|---------|--------------|-----------|---------|\n"
        
        for result in results.sorted(by: { $0.metrics.f1Score > $1.metrics.f1Score }) {
            let tier = result.metrics.f1Score >= 0.85 ? "🟢" : (result.metrics.f1Score >= 0.75 ? "🟡" : "🔴")
            
            table += "| \(result.modelId) "
            table += "| \(String(format: "%.3f", result.metrics.f1Score)) "
            table += "| \(String(format: "%.3f", result.metrics.accuracy)) "
            table += "| \(String(format: "%.3f", result.metrics.precision)) "
            table += "| \(String(format: "%.3f", result.metrics.recall)) "
            table += "| \(String(format: "%.3f", result.metrics.calibrationError)) "
            table += "| \(String(format: "%.2f", result.metrics.averageResponseTime))s "
            table += "| \(tier) |\n"
        }
        
        return table
    }
}

class ReportGenerator {
    private let reportsDirectory: URL
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.reportsDirectory = homeDir.appendingPathComponent("src/shoulder/evaluation/reports")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    func generateReport(for result: EvaluationResult) async throws {
        let timestamp = DateFormatters.fileDateTime.string(from: result.evaluationDate)
        let reportName = "evaluation_\(result.modelId.replacingOccurrences(of: "/", with: "_"))_\(timestamp)"
        
        // Generate Markdown report
        let markdownReport = generateMarkdownReport(for: result)
        let markdownURL = reportsDirectory.appendingPathComponent("\(reportName).md")
        try markdownReport.write(to: markdownURL, atomically: true, encoding: .utf8)
        
        // Generate JSON report with detailed data
        let jsonReport = try generateJSONReport(for: result)
        let jsonURL = reportsDirectory.appendingPathComponent("\(reportName).json")
        try jsonReport.write(to: jsonURL)
        
        print("📝 Generated evaluation report: \(markdownURL.lastPathComponent)")
    }
    
    func generateComparisonReport(_ results: [EvaluationResult]) -> ModelComparisonReport {
        return ModelComparisonReport(results: results)
    }
    
    private func generateMarkdownReport(for result: EvaluationResult) -> String {
        let metricsCalculator = MetricsCalculator()
        let performanceSummary = metricsCalculator.generatePerformanceSummary(
            metrics: result.metrics,
            modelId: result.modelId
        )
        
        var report = """
        # Evaluation Report: \(result.modelId)
        
        **Evaluation Date:** \(DateFormatters.readableDateTime.string(from: result.evaluationDate))
        **Sample Count:** \(result.sampleCount)
        **Evaluation Time:** \(String(format: "%.2f", result.evaluationTime))s
        
        ## Performance Summary
        
        \(performanceSummary)
        
        ## Detailed Metrics
        
        ### Focus Area Performance
        """
        
        for (area, performance) in result.metrics.focusAreaPerformance.sorted(by: { $0.key < $1.key }) {
            report += "\n- **\(area.capitalized):** \(String(format: "%.3f", performance)) (\(String(format: "%.1f%%", performance * 100)))"
        }
        
        report += "\n\n### App Context Accuracy\n"
        
        let topApps = result.metrics.appContextAccuracy.sorted { $0.value > $1.value }.prefix(10)
        for (app, accuracy) in topApps {
            report += "\n- **\(app):** \(String(format: "%.3f", accuracy)) (\(String(format: "%.1f%%", accuracy * 100)))"
        }
        
        report += "\n\n### Error Analysis\n"
        
        let errorAnalysis = analyzeErrors(from: result.detailedResults)
        report += "\n\(errorAnalysis)\n"
        
        report += "\n### Recommendations\n"
        
        let recommendations = generateRecommendations(for: result)
        for recommendation in recommendations {
            report += "\n- \(recommendation)"
        }
        
        report += "\n\n---\n*Generated by Shoulder Evaluation Suite*"
        
        return report
    }
    
    private func generateJSONReport(for result: EvaluationResult) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(result)
    }
    
    private func analyzeErrors(from results: [SampleResult]) -> String {
        let incorrectResults = results.filter { !$0.isCorrect }
        guard !incorrectResults.isEmpty else {
            return "🎉 **Perfect Score!** No classification errors found."
        }
        
        var analysis = "**Common Error Patterns:**\n"
        
        // Analyze false positives (predicted focused, actually distracted)
        let falsePositives = incorrectResults.filter { $0.prediction.is_valid && !$0.groundTruth.isValid }
        if !falsePositives.isEmpty {
            analysis += "\n**False Positives (\(falsePositives.count)):** Model incorrectly classified as focused\n"
            
            let fpByApp = Dictionary(grouping: falsePositives) { $0.groundTruth.appName }
            let topFPApps = fpByApp.sorted { $0.value.count > $1.value.count }.prefix(3)
            
            for (app, errors) in topFPApps {
                analysis += "- \(app): \(errors.count) errors\n"
            }
        }
        
        // Analyze false negatives (predicted distracted, actually focused)
        let falseNegatives = incorrectResults.filter { !$0.prediction.is_valid && $0.groundTruth.isValid }
        if !falseNegatives.isEmpty {
            analysis += "\n**False Negatives (\(falseNegatives.count)):** Model incorrectly classified as distracted\n"
            
            let fnByArea = Dictionary(grouping: falseNegatives) { $0.groundTruth.focusArea }
            let topFNAreas = fnByArea.sorted { $0.value.count > $1.value.count }.prefix(3)
            
            for (area, errors) in topFNAreas {
                analysis += "- \(area): \(errors.count) errors\n"
            }
        }
        
        // Confidence analysis for errors
        let lowConfidenceErrors = incorrectResults.filter { $0.prediction.confidence < 0.5 }
        let highConfidenceErrors = incorrectResults.filter { $0.prediction.confidence >= 0.8 }
        
        if !lowConfidenceErrors.isEmpty {
            analysis += "\n**Low Confidence Errors (\(lowConfidenceErrors.count)):** Model was uncertain but still wrong"
        }
        
        if !highConfidenceErrors.isEmpty {
            analysis += "\n**High Confidence Errors (\(highConfidenceErrors.count)):** Model was very confident but wrong"
        }
        
        return analysis
    }
    
    private func generateRecommendations(for result: EvaluationResult) -> [String] {
        var recommendations: [String] = []
        
        let metrics = result.metrics
        
        // Performance-based recommendations
        if metrics.f1Score < 0.75 {
            recommendations.append("Consider switching to a more capable model or improving training data")
        }
        
        if metrics.precision < 0.8 {
            recommendations.append("High false positive rate - consider stricter classification criteria")
        }
        
        if metrics.recall < 0.8 {
            recommendations.append("High false negative rate - model may be too strict")
        }
        
        if metrics.calibrationError > 0.15 {
            recommendations.append("Poor confidence calibration - confidence scores don't match accuracy")
        }
        
        if metrics.averageResponseTime > 10.0 {
            recommendations.append("Consider using a faster model for better user experience")
        }
        
        if metrics.failureRate > 0.05 {
            recommendations.append("High failure rate - investigate model stability issues")
        }
        
        // Focus area specific recommendations
        let weakAreas = metrics.focusAreaPerformance.filter { $0.value < 0.7 }
        if !weakAreas.isEmpty {
            let areas = weakAreas.keys.joined(separator: ", ")
            recommendations.append("Poor performance in: \(areas) - need more training data for these areas")
        }
        
        // App context recommendations
        let poorAppPerformance = metrics.appContextAccuracy.filter { $0.value < 0.6 }
        if poorAppPerformance.count > 3 {
            recommendations.append("Inconsistent performance across apps - consider app-specific tuning")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Excellent performance! Model is ready for production use")
        }
        
        return recommendations
    }
    
    func generateComparisonReportMarkdown(_ comparison: ModelComparisonReport) -> String {
        var report = """
        # Model Comparison Report
        
        **Evaluated Models:** \(comparison.results.count)
        **Best Model:** \(comparison.bestModel ?? "None")
        
        ## Performance Comparison
        
        \(comparison.comparisonTable)
        
        ## Recommendations
        
        """
        
        for recommendation in comparison.recommendations {
            report += "\n\(recommendation)"
        }
        
        report += "\n\n## Detailed Analysis\n"
        
        // Add trend analysis
        report += "\n### Performance Trends\n"
        
        let avgF1 = comparison.results.map { $0.metrics.f1Score }.reduce(0, +) / Double(comparison.results.count)
        let avgResponseTime = comparison.results.map { $0.metrics.averageResponseTime }.reduce(0, +) / Double(comparison.results.count)
        
        report += "\n- **Average F1 Score:** \(String(format: "%.3f", avgF1))"
        report += "\n- **Average Response Time:** \(String(format: "%.2f", avgResponseTime))s"
        
        // Local vs Remote analysis
        let localResults = comparison.results.filter { !$0.modelId.hasPrefix("gpt") }
        let remoteResults = comparison.results.filter { $0.modelId.hasPrefix("gpt") }
        
        if !localResults.isEmpty && !remoteResults.isEmpty {
            let localAvgF1 = localResults.map { $0.metrics.f1Score }.reduce(0, +) / Double(localResults.count)
            let remoteAvgF1 = remoteResults.map { $0.metrics.f1Score }.reduce(0, +) / Double(remoteResults.count)
            
            report += "\n\n### Local vs Remote Models\n"
            report += "\n- **Local Models Avg F1:** \(String(format: "%.3f", localAvgF1))"
            report += "\n- **Remote Models Avg F1:** \(String(format: "%.3f", remoteAvgF1))"
            
            if localAvgF1 > remoteAvgF1 {
                report += "\n- **Winner:** Local models perform better on average"
            } else {
                report += "\n- **Winner:** Remote models perform better on average"
            }
        }
        
        report += "\n\n---\n*Generated by Shoulder Evaluation Suite*"
        
        return report
    }
}

// MARK: - Date Formatters
extension DateFormatters {
    static let fileDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let readableDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
}