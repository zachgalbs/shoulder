//
//  GroundTruthDataset.swift
//  shoulder
//
//  Created by Claude Code on 9/3/25.
//

import Foundation

struct GroundTruthSample: Codable {
    let id: String
    let ocrText: String
    let appName: String
    let windowTitle: String?
    let userFocus: String
    let isValid: Bool // Ground truth label
    let confidence: Double // Annotator confidence in label
    let focusArea: String // e.g., "coding", "writing", "research"
    let annotatorId: String
    let annotationDate: Date
    let ocrConfidence: Double? // OCR system confidence
    let screenshotPath: String? // Path to original screenshot
    let notes: String? // Additional annotator notes
    
    init(
        id: String = UUID().uuidString,
        ocrText: String,
        appName: String,
        windowTitle: String? = nil,
        userFocus: String,
        isValid: Bool,
        confidence: Double = 1.0,
        focusArea: String,
        annotatorId: String = "system",
        annotationDate: Date = Date(),
        ocrConfidence: Double? = nil,
        screenshotPath: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.ocrText = ocrText
        self.appName = appName
        self.windowTitle = windowTitle
        self.userFocus = userFocus
        self.isValid = isValid
        self.confidence = confidence
        self.focusArea = focusArea
        self.annotatorId = annotatorId
        self.annotationDate = annotationDate
        self.ocrConfidence = ocrConfidence
        self.screenshotPath = screenshotPath
        self.notes = notes
    }
}

struct AnnotationGuidelines {
    static let focusDefinition = """
    Is this activity directly contributing to the user's stated focus goal?
    
    Guidelines:
    - Mark as VALID (true) ONLY if the activity clearly contributes to the stated focus
    - Mark as INVALID (false) for unrelated activities (entertainment, social media, unrelated browsing, etc.)
    - Be strict: if in doubt, mark as invalid
    - Consider the application context and visible content together
    
    Examples for focus "Developing my iOS application":
    ✅ VALID: Xcode with Swift code, iOS documentation, Stack Overflow Swift questions
    ❌ INVALID: Social media, news websites, entertainment videos, personal email
    """
    
    static let confidenceScale = """
    Confidence Scale:
    1.0 - Completely certain about the label
    0.8 - Very confident
    0.6 - Somewhat confident  
    0.4 - Uncertain
    0.2 - Very uncertain
    """
}

class GroundTruthDataset {
    private let datasetDirectory: URL
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.datasetDirectory = homeDir.appendingPathComponent("src/shoulder/evaluation/ground_truth")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: datasetDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    func loadSamples(maxCount: Int? = nil, shuffle: Bool = true) async throws -> [GroundTruthSample] {
        let jsonFiles = try FileManager.default.contentsOfDirectory(at: datasetDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        
        var allSamples: [GroundTruthSample] = []
        
        for jsonFile in jsonFiles {
            do {
                let data = try Data(contentsOf: jsonFile)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Try to load as array first, then single sample
                if let samples = try? decoder.decode([GroundTruthSample].self, from: data) {
                    allSamples.append(contentsOf: samples)
                } else if let sample = try? decoder.decode(GroundTruthSample.self, from: data) {
                    allSamples.append(sample)
                }
            } catch {
                print("Failed to load ground truth file \(jsonFile.lastPathComponent): \(error)")
            }
        }
        
        if shuffle {
            allSamples.shuffle()
        }
        
        if let maxCount = maxCount {
            return Array(allSamples.prefix(maxCount))
        }
        
        return allSamples
    }
    
    func saveSample(_ sample: GroundTruthSample) throws {
        let filename = "sample_\(sample.id).json"
        let fileURL = datasetDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(sample)
        try data.write(to: fileURL)
    }
    
    func saveSamples(_ samples: [GroundTruthSample], filename: String = "ground_truth_batch.json") throws {
        let fileURL = datasetDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(samples)
        try data.write(to: fileURL)
    }
    
    func loadSamplesByFocusArea(_ focusArea: String) async throws -> [GroundTruthSample] {
        let allSamples = try await loadSamples()
        return allSamples.filter { $0.focusArea.lowercased() == focusArea.lowercased() }
    }
    
    func loadSamplesByApp(_ appName: String) async throws -> [GroundTruthSample] {
        let allSamples = try await loadSamples()
        return allSamples.filter { $0.appName.lowercased().contains(appName.lowercased()) }
    }
    
    func getDatasetStatistics() async throws -> DatasetStatistics {
        let samples = try await loadSamples(shuffle: false)
        
        let totalCount = samples.count
        let validCount = samples.filter { $0.isValid }.count
        let invalidCount = totalCount - validCount
        
        let focusAreaCounts = Dictionary(grouping: samples, by: { $0.focusArea })
            .mapValues { $0.count }
        
        let appCounts = Dictionary(grouping: samples, by: { $0.appName })
            .mapValues { $0.count }
        
        let annotatorCounts = Dictionary(grouping: samples, by: { $0.annotatorId })
            .mapValues { $0.count }
        
        let averageConfidence = samples.map { $0.confidence }.reduce(0, +) / Double(totalCount)
        
        return DatasetStatistics(
            totalSamples: totalCount,
            validSamples: validCount,
            invalidSamples: invalidCount,
            focusAreaDistribution: focusAreaCounts,
            appDistribution: appCounts,
            annotatorDistribution: annotatorCounts,
            averageAnnotatorConfidence: averageConfidence
        )
    }
    
    func validateAnnotatorAgreement(sampleIds: [String]) async throws -> Double {
        let samples = try await loadSamples(shuffle: false)
        
        // Group samples by ID to find multiple annotations
        let groupedSamples = Dictionary(grouping: samples.filter { sampleIds.contains($0.id) }, by: { $0.id })
        
        var agreements = 0
        var totalComparisons = 0
        
        for (_, annotations) in groupedSamples {
            if annotations.count >= 2 {
                for i in 0..<annotations.count {
                    for j in (i+1)..<annotations.count {
                        let agree = annotations[i].isValid == annotations[j].isValid
                        if agree { agreements += 1 }
                        totalComparisons += 1
                    }
                }
            }
        }
        
        return totalComparisons > 0 ? Double(agreements) / Double(totalComparisons) : 0.0
    }
    
    func createSampleFromAnalysis(_ analysis: MLXAnalysisResult, ocrText: String, appName: String, windowTitle: String?, userFocus: String, humanLabel: Bool, annotatorId: String = "human", notes: String? = nil) -> GroundTruthSample {
        // Determine focus area from user focus and app context
        let focusArea = determineFocusArea(userFocus: userFocus, appName: appName, ocrText: ocrText)
        
        return GroundTruthSample(
            ocrText: ocrText,
            appName: appName,
            windowTitle: windowTitle,
            userFocus: userFocus,
            isValid: humanLabel,
            confidence: 1.0, // Human annotator is fully confident
            focusArea: focusArea,
            annotatorId: annotatorId,
            notes: notes
        )
    }
    
    private func determineFocusArea(userFocus: String, appName: String, ocrText: String) -> String {
        let focusLower = userFocus.lowercased()
        let appLower = appName.lowercased()
        let textLower = ocrText.lowercased()
        
        // Coding patterns
        if focusLower.contains("code") || focusLower.contains("develop") || focusLower.contains("program") ||
           appLower.contains("xcode") || appLower.contains("vscode") || appLower.contains("terminal") ||
           textLower.contains("function") || textLower.contains("class") || textLower.contains("import") {
            return "coding"
        }
        
        // Writing patterns
        if focusLower.contains("writ") || focusLower.contains("document") || focusLower.contains("blog") ||
           appLower.contains("pages") || appLower.contains("word") || appLower.contains("notion") {
            return "writing"
        }
        
        // Research patterns
        if focusLower.contains("research") || focusLower.contains("learn") || focusLower.contains("study") ||
           appLower.contains("safari") || appLower.contains("chrome") || appLower.contains("firefox") {
            return "research"
        }
        
        // Communication patterns
        if focusLower.contains("meet") || focusLower.contains("email") || focusLower.contains("message") ||
           appLower.contains("slack") || appLower.contains("zoom") || appLower.contains("mail") {
            return "communication"
        }
        
        // Design patterns
        if focusLower.contains("design") || focusLower.contains("ui") || focusLower.contains("mockup") ||
           appLower.contains("figma") || appLower.contains("sketch") || appLower.contains("photoshop") {
            return "design"
        }
        
        return "other"
    }
}

struct DatasetStatistics {
    let totalSamples: Int
    let validSamples: Int
    let invalidSamples: Int
    let focusAreaDistribution: [String: Int]
    let appDistribution: [String: Int]
    let annotatorDistribution: [String: Int]
    let averageAnnotatorConfidence: Double
    
    var classBalance: Double {
        return Double(min(validSamples, invalidSamples)) / Double(max(validSamples, invalidSamples))
    }
}