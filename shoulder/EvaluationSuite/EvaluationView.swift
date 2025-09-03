//
//  EvaluationView.swift
//  shoulder
//
//  Created by Claude Code on 9/3/25.
//

import SwiftUI

struct EvaluationView: View {
    @ObservedObject var evaluationSuite: EvaluationSuite
    @State private var selectedModelForEvaluation = ""
    @State private var maxSamples = 100
    @State private var showingResults = false
    @State private var showingComparison = false
    @State private var evaluateAllModels = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.large) {
                // Header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.title2)
                            .foregroundColor(DesignSystem.Colors.accentBlue)
                        
                        Text("Model Evaluation Suite")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    Text("Evaluate and compare AI model classification performance")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal)
                
                // Status Card
                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Text(evaluationSuite.currentStatus)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        if evaluationSuite.isEvaluating {
                            VStack(alignment: .trailing, spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                
                                Text("\(Int(evaluationSuite.evaluationProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        } else {
                            Image(systemName: evaluationSuite.lastEvaluationResult != nil ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(evaluationSuite.lastEvaluationResult != nil ? DesignSystem.Colors.activeGreen : DesignSystem.Colors.textTertiary)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.small)
                    
                    if evaluationSuite.isEvaluating {
                        ProgressView(value: evaluationSuite.evaluationProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.top, DesignSystem.Spacing.small)
                    }
                }
                .padding(.horizontal)
                
                // Evaluation Configuration
                GroupBox("Evaluation Settings") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        // Model Selection
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            Text("Model to Evaluate")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Picker("Model", selection: $selectedModelForEvaluation) {
                                Text("Current Model").tag("")
                                ForEach(AIModelConfiguration.availableModels, id: \.id) { model in
                                    Text(model.displayName).tag(model.id)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        // Sample Count
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            HStack {
                                Text("Max Samples")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Spacer()
                                
                                Text("\(maxSamples)")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(maxSamples) },
                                set: { maxSamples = Int($0) }
                            ), in: 10...500, step: 10)
                        }
                        
                        // Evaluate All Toggle
                        Toggle("Evaluate All Models", isOn: $evaluateAllModels)
                            .font(.caption)
                    }
                    .padding(.vertical, DesignSystem.Spacing.small)
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Button(action: startEvaluation) {
                        HStack {
                            Image(systemName: evaluateAllModels ? "gearshape.2" : "gearshape")
                            Text(evaluateAllModels ? "Evaluate All Models" : "Start Evaluation")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(evaluationSuite.isEvaluating)
                    
                    HStack(spacing: DesignSystem.Spacing.medium) {
                        Button("View Results") {
                            showingResults = true
                        }
                        .disabled(evaluationSuite.lastEvaluationResult == nil)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.backgroundTertiary)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .cornerRadius(8)
                        
                        Button("Compare Models") {
                            showingComparison = true
                        }
                        .disabled(evaluationSuite.evaluationHistory.count < 2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.backgroundTertiary)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // Recent Results
                if !evaluationSuite.evaluationHistory.isEmpty {
                    GroupBox("Recent Evaluations") {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                ForEach(evaluationSuite.evaluationHistory.suffix(5).reversed(), id: \.evaluationDate) { result in
                                    EvaluationResultRow(result: result)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Evaluation")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingResults) {
            if let result = evaluationSuite.lastEvaluationResult {
                EvaluationResultDetailView(result: result)
            }
        }
        .sheet(isPresented: $showingComparison) {
            ModelComparisonView(evaluationSuite: evaluationSuite)
        }
    }
    
    private func startEvaluation() {
        Task {
            do {
                if evaluateAllModels {
                    _ = try await evaluationSuite.evaluateAllModels(maxSamples: maxSamples)
                } else {
                    let modelId = selectedModelForEvaluation.isEmpty ? nil : selectedModelForEvaluation
                    _ = try await evaluationSuite.evaluateModel(modelId: modelId, maxSamples: maxSamples)
                }
            } catch {
                print("Evaluation failed: \(error)")
            }
        }
    }
}

struct EvaluationResultRow: View {
    let result: EvaluationResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.modelId)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(DateFormatters.readable.string(from: result.evaluationDate))
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("F1: \(String(format: "%.3f", result.metrics.f1Score))")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(result.sampleCount) samples")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            performanceTierIcon(f1Score: result.metrics.f1Score)
        }
        .padding(.vertical, 4)
    }
    
    private func performanceTierIcon(f1Score: Double) -> some View {
        let (icon, color) = f1Score >= 0.85 ? ("checkmark.circle.fill", DesignSystem.Colors.activeGreen) :
                           f1Score >= 0.75 ? ("exclamationmark.triangle.fill", DesignSystem.Colors.warningYellow) :
                           ("xmark.circle.fill", DesignSystem.Colors.destructiveRed)
        
        return Image(systemName: icon)
            .font(.caption)
            .foregroundColor(color)
    }
}

struct EvaluationResultDetailView: View {
    let result: EvaluationResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    // Header
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                        Text(result.modelId)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Evaluated on \(DateFormatters.readable.string(from: result.evaluationDate))")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    // Key Metrics
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.medium) {
                        MetricCard(title: "Accuracy", value: result.metrics.accuracy, format: "%.3f")
                        MetricCard(title: "F1-Score", value: result.metrics.f1Score, format: "%.3f")
                        MetricCard(title: "Precision", value: result.metrics.precision, format: "%.3f")
                        MetricCard(title: "Recall", value: result.metrics.recall, format: "%.3f")
                        MetricCard(title: "Response Time", value: result.metrics.averageResponseTime, format: "%.2fs")
                        MetricCard(title: "Failure Rate", value: result.metrics.failureRate * 100, format: "%.1f%%")
                    }
                    
                    // Focus Area Performance
                    if !result.metrics.focusAreaPerformance.isEmpty {
                        GroupBox("Focus Area Performance") {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                ForEach(result.metrics.focusAreaPerformance.sorted(by: { $0.key < $1.key }), id: \.key) { area, performance in
                                    HStack {
                                        Text(area.capitalized)
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        Text(String(format: "%.3f", performance))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        performanceBar(value: performance)
                                            .frame(width: 50, height: 4)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
    
    private func performanceBar(value: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(DesignSystem.Colors.backgroundTertiary)
                
                Rectangle()
                    .fill(value >= 0.8 ? DesignSystem.Colors.activeGreen :
                          value >= 0.6 ? DesignSystem.Colors.warningYellow :
                          DesignSystem.Colors.destructiveRed)
                    .frame(width: geometry.size.width * value)
            }
        }
        .cornerRadius(2)
    }
}

struct MetricCard: View {
    let title: String
    let value: Double
    let format: String
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Text(String(format: format, value))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ModelComparisonView: View {
    @ObservedObject var evaluationSuite: EvaluationSuite
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    if evaluationSuite.evaluationHistory.count >= 2 {
                        let comparison = evaluationSuite.generateComparisonReport(evaluationSuite.evaluationHistory)
                        
                        // Best Model
                        if let bestModel = comparison.bestModel {
                            GroupBox("🏆 Best Performer") {
                                Text(bestModel)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        // Recommendations
                        if !comparison.recommendations.isEmpty {
                            GroupBox("Recommendations") {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                    ForEach(comparison.recommendations, id: \.self) { recommendation in
                                        Text(recommendation)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        
                        // Comparison Table
                        GroupBox("Performance Comparison") {
                            ScrollView(.horizontal) {
                                Text(comparison.comparisonTable)
                                    .font(.caption)
                                    .fontFamily(.monospaced)
                            }
                        }
                        
                    } else {
                        Text("Need at least 2 evaluation results to compare models")
                            .font(.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Model Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

// MARK: - Date Formatters Extension
extension DateFormatters {
    static let readable: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    // Create a mock MLXLLMManager for preview
    let mockMLXManager = MLXLLMManager()
    let evaluationSuite = EvaluationSuite(mlxManager: mockMLXManager)
    
    return EvaluationView(evaluationSuite: evaluationSuite)
}