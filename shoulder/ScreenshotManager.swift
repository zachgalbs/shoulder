//
//  ScreenshotManager.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/3/25.
//

import Foundation
import AppKit
import ScreenCaptureKit
import Vision

// MARK: - SpatialText Model

struct SpatialText {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let centerY: CGFloat
    let centerX: CGFloat
    
    init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.centerY = boundingBox.midY
        self.centerX = boundingBox.midX
    }
}

// MARK: - ScreenshotManager

class ScreenshotManager: ObservableObject {
    private var timer: Timer?
    private let captureInterval: TimeInterval = 60.0 // 1 minute
    private var baseDirectoryURL: URL?
    private var mlxLLMManager: MLXLLMManager?
    @Published var lastOCRText: String?
    
    // Queue for pending analyses when LLM server isn't ready
    private struct PendingAnalysis {
        let ocrText: String
        let appName: String
        let timestamp: Date
    }
    private var pendingAnalyses: [PendingAnalysis] = []
    
    init() {
        setupDirectories()
    }
    
    func setMLXLLMManager(_ manager: MLXLLMManager) {
        self.mlxLLMManager = manager
        
        // Monitor when server becomes ready to process queued analyses
        Task {
            await monitorServerReadiness()
        }
    }
    
    @MainActor
    private func monitorServerReadiness() async {
        guard let mlxManager = mlxLLMManager else { return }
        
        // Wait for model to be ready
        while !mlxManager.isModelReady {
            try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s
        }
        
        // Process any pending analyses
        await processPendingAnalyses()
    }
    
    @MainActor
    private func processPendingAnalyses() async {
        guard let mlxManager = mlxLLMManager,
              !pendingAnalyses.isEmpty else { return }
        
        
        for pending in pendingAnalyses {
            do {
                let result = try await mlxManager.analyzeScreenshot(
                    ocrText: pending.ocrText,
                    appName: pending.appName,
                    windowTitle: nil
                )
                
                
            } catch {
            }
        }
        
        pendingAnalyses.removeAll()
    }
    
    deinit {
        stopCapturing()
    }
    
    private func setupDirectories() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        baseDirectoryURL = homeDirectory.appendingPathComponent("src/shoulder/screenshots")
        
        // Create the directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: baseDirectoryURL!, withIntermediateDirectories: true, attributes: nil)
        } catch {
        }
    }
    
    func startCapturing() {
        guard timer == nil else { return }
        
        // Take first screenshot immediately
        captureScreenshot()
        
        // Set up timer for regular captures
        timer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { _ in
            self.captureScreenshot()
        }
        
    }
    
    func stopCapturing() {
        timer?.invalidate()
        timer = nil
    }
    
    private func captureScreenshot() {
        guard let baseURL = baseDirectoryURL else {
            return
        }
        
        // Create date-based folder structure
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        let todayFolderURL = baseURL.appendingPathComponent(todayString)
        
        // Create today's folder if needed
        do {
            try FileManager.default.createDirectory(at: todayFolderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return
        }
        
        // Generate timestamp filename
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let timeString = timeFormatter.string(from: Date())
        let filename = "screenshot-\(timeString).png"
        let fileURL = todayFolderURL.appendingPathComponent(filename)
        
        
        // Capture screenshot using CGDisplayCreateImage
        if let displayID = CGMainDisplayID() as CGDirectDisplayID?,
           let image = CGDisplayCreateImage(displayID) {
            
            
            // Convert to NSImage and save as PNG
            let nsImage = NSImage(cgImage: image, size: .zero)
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                
                do {
                    try pngData.write(to: fileURL)
                    
                    // Process OCR asynchronously
                    processOCR(for: image, at: todayFolderURL, filename: timeString)
                } catch {
                }
            }
        } else {
        }
    }
    
    private func processOCR(for cgImage: CGImage, at folderURL: URL, filename: String) {
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleOCRResult(request: request, error: error, folderURL: folderURL, filename: filename)
        }
        
        // Configure for best accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        
        // Process the image
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .utility).async {
            do {
                try handler.perform([request])
            } catch {
            }
        }
    }
    
    private func handleOCRResult(request: VNRequest, error: Error?, folderURL: URL, filename: String) {
        guard error == nil else {
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        
        // Extract text with spatial information
        var spatialTexts: [SpatialText] = []
        var debugTexts: [String] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let spatialText = SpatialText(
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: observation.boundingBox
            )
            spatialTexts.append(spatialText)
            
            // Collect first 5 text snippets for debugging
            if debugTexts.count < 5 {
                debugTexts.append("\"\(topCandidate.string)\" (conf: \(String(format: "%.0f%%", topCandidate.confidence * 100)))")
            }
        }
        
        
        // Create LLM-optimized markdown content
        let markdownContent = createOptimizedMarkdownContent(
            spatialTexts: spatialTexts,
            timestamp: filename
        )
        
        // Save markdown file
        let markdownFilename = "screenshot-\(filename).md"
        let markdownURL = folderURL.appendingPathComponent(markdownFilename)
        
        do {
            try markdownContent.write(to: markdownURL, atomically: true, encoding: .utf8)
            
            // Store the OCR text for potential LLM analysis
            DispatchQueue.main.async { [weak self] in
                let ocrText = spatialTexts.map { $0.text }.joined(separator: " ")
                self?.lastOCRText = ocrText
                
                // Trigger MLX analysis if manager is available
                if let mlxManager = self?.mlxLLMManager {
                    self?.triggerMLXAnalysis(ocrText: ocrText, with: mlxManager)
                }
            }
        } catch {
        }
    }
    
    private func createOptimizedMarkdownContent(spatialTexts: [SpatialText], timestamp: String) -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // Sort text by reading order (top to bottom, left to right)
        let sortedTexts = spatialTexts.sorted { first, second in
            let yThreshold: CGFloat = 0.02 // Consider items on same line if within 2% of screen height
            if abs(first.centerY - second.centerY) < yThreshold {
                return first.centerX < second.centerX // Same line: left to right
            }
            return first.centerY > second.centerY // Different lines: top to bottom (flipped coordinates)
        }
        
        // Group text into coherent sections
        let groupedSections = groupTextIntoSections(sortedTexts)
        
        // Calculate statistics
        let totalText = spatialTexts.count
        let highConfidenceCount = spatialTexts.filter { $0.confidence > 0.8 }.count
        let avgConfidence = spatialTexts.isEmpty ? 0.0 : spatialTexts.map { $0.confidence }.reduce(0, +) / Float(spatialTexts.count)
        
        var markdown = """
        # Screenshot Analysis - \(timestamp)
        
        **Metadata:**
        - Captured: \(formatter.string(from: date))
        - Total Text Elements: \(totalText)
        - High Confidence (>80%): \(highConfidenceCount)/\(totalText)
        - Average Confidence: \(String(format: "%.1f%%", avgConfidence * 100))
        - Content Regions: \(groupedSections.count)
        
        ---
        
        """
        
        if groupedSections.isEmpty {
            markdown += "\n_No text detected in screenshot._\n"
        } else {
            for (index, section) in groupedSections.enumerated() {
                markdown += "\n## Region \(index + 1)\n\n"
                markdown += reconstructTextFlow(from: section)
                markdown += "\n"
            }
        }
        
        // Add spatial debugging info for development
        markdown += """
        
        ---
        
        ## Debug Info
        - Screen regions detected: \(groupedSections.count)
        - Processing method: Spatial grouping with reading order reconstruction
        
        """
        
        return markdown
    }
    
    private func groupTextIntoSections(_ sortedTexts: [SpatialText]) -> [[SpatialText]] {
        guard !sortedTexts.isEmpty else { return [] }
        
        var sections: [[SpatialText]] = []
        var currentSection: [SpatialText] = [sortedTexts[0]]
        
        for i in 1..<sortedTexts.count {
            let current = sortedTexts[i]
            let previous = sortedTexts[i-1]
            
            // Group items that are vertically close (within 15% of screen height)
            let verticalThreshold: CGFloat = 0.15
            let horizontalThreshold: CGFloat = 0.3
            
            let verticalDistance = abs(current.centerY - previous.centerY)
            let horizontalDistance = abs(current.centerX - previous.centerX)
            
            // Start new section if there's a significant spatial gap
            if verticalDistance > verticalThreshold || horizontalDistance > horizontalThreshold {
                if !currentSection.isEmpty {
                    sections.append(currentSection)
                }
                currentSection = [current]
            } else {
                currentSection.append(current)
            }
        }
        
        // Add the last section
        if !currentSection.isEmpty {
            sections.append(currentSection)
        }
        
        return sections
    }
    
    private func reconstructTextFlow(from texts: [SpatialText]) -> String {
        guard !texts.isEmpty else { return "_Empty section_" }
        
        // Detect if this looks like code/terminal content
        let codeIndicators = ["$", "git", "npm", "cd", "ls", "mkdir", "->", "=>", "function", "import"]
        let containsCode = texts.contains { text in
            codeIndicators.contains { indicator in
                text.text.lowercased().contains(indicator.lowercased())
            }
        }
        
        if containsCode {
            // Format as code block
            let codeContent = texts.map { $0.text }.joined(separator: " ")
            return "```\n\(codeContent)\n```\n"
        }
        
        // Reconstruct natural text flow
        var result = ""
        var currentLine = ""
        let lineThreshold: CGFloat = 0.02 // Items within 2% height are on same line
        
        for (index, text) in texts.enumerated() {
            if index == 0 {
                currentLine = text.text
            } else {
                let previousText = texts[index - 1]
                let onSameLine = abs(text.centerY - previousText.centerY) < lineThreshold
                
                if onSameLine {
                    currentLine += " " + text.text
                } else {
                    result += currentLine + "\n"
                    currentLine = text.text
                }
            }
        }
        
        // Add the last line
        if !currentLine.isEmpty {
            result += currentLine + "\n"
        }
        
        return result
    }
    
    @MainActor
    private func triggerMLXAnalysis(ocrText: String, with mlxManager: MLXLLMManager) {
        // Get current app context (simplified for demo)
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        
        
        // Check if model is ready
        if !mlxManager.isModelReady {
            pendingAnalyses.append(PendingAnalysis(
                ocrText: ocrText,
                appName: appName,
                timestamp: Date()
            ))
            return
        }
        
        Task {
            do {
                let result = try await mlxManager.analyzeScreenshot(
                    ocrText: ocrText,
                    appName: appName,
                    windowTitle: nil
                )
                
                
            } catch {
                
                // If it failed due to model not loaded, queue it
                if case MLXLLMError.modelNotLoaded = error {
                    pendingAnalyses.append(PendingAnalysis(
                        ocrText: ocrText,
                        appName: appName,
                        timestamp: Date()
                    ))
                }
            }
        }
    }
}
