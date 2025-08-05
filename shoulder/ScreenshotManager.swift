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

class ScreenshotManager: ObservableObject {
    private var timer: Timer?
    private let captureInterval: TimeInterval = 60.0 // 1 minute
    private var baseDirectoryURL: URL?
    private var llmAnalysisManager: LLMAnalysisManager?
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
    
    func setLLMManager(_ manager: LLMAnalysisManager) {
        self.llmAnalysisManager = manager
        
        // Monitor when server becomes ready to process queued analyses
        Task {
            await monitorServerReadiness()
        }
    }
    
    @MainActor
    private func monitorServerReadiness() async {
        guard let llmManager = llmAnalysisManager else { return }
        
        // Wait for server to be ready
        while !llmManager.isServerReady {
            try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s
        }
        
        // Process any pending analyses
        await processPendingAnalyses()
    }
    
    @MainActor
    private func processPendingAnalyses() async {
        guard let llmManager = llmAnalysisManager,
              !pendingAnalyses.isEmpty else { return }
        
        print("[Screenshot] 📦 Processing \(pendingAnalyses.count) queued analyses...")
        
        for pending in pendingAnalyses {
            do {
                let result = try await llmManager.analyzeScreenshot(
                    ocrText: pending.ocrText,
                    appName: pending.appName,
                    windowTitle: nil
                )
                
                print("[AI] ✅ Queued analysis processed:")
                print("[AI] \(result.is_valid ? "✅" : "❌") Valid: \(result.is_valid)")
                print("[AI] 📊 Activity: \(result.detected_activity)")
                
            } catch {
                print("[AI] ❌ Failed to process queued analysis: \(error)")
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
            print("Screenshot directory ready: \(baseDirectoryURL!.path)")
        } catch {
            print("Failed to create screenshot directory: \(error)")
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
        
        print("Screenshot capture started (every \(Int(captureInterval)) seconds)")
    }
    
    func stopCapturing() {
        timer?.invalidate()
        timer = nil
        print("Screenshot capture stopped")
    }
    
    private func captureScreenshot() {
        guard let baseURL = baseDirectoryURL else {
            print("[Screenshot] ❌ Directory not available")
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
            print("[Screenshot] ❌ Failed to create today's folder: \(error)")
            return
        }
        
        // Generate timestamp filename
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let timeString = timeFormatter.string(from: Date())
        let filename = "screenshot-\(timeString).png"
        let fileURL = todayFolderURL.appendingPathComponent(filename)
        
        print("\n[Screenshot] 📸 === Starting Screenshot Pipeline ===")
        print("[Screenshot] 📸 Step 1: Capturing screen at \(Date())")
        
        // Capture screenshot using CGDisplayCreateImage
        if let displayID = CGMainDisplayID() as CGDirectDisplayID?,
           let image = CGDisplayCreateImage(displayID) {
            
            print("[Screenshot] 📸 Step 2: Screen captured (\(image.width)x\(image.height) pixels)")
            
            // Convert to NSImage and save as PNG
            let nsImage = NSImage(cgImage: image, size: .zero)
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                
                do {
                    try pngData.write(to: fileURL)
                    print("[Screenshot] 📸 Step 3: Saved to: \(filename)")
                    print("[Screenshot] 📸 Step 4: Starting OCR processing...")
                    
                    // Process OCR asynchronously
                    processOCR(for: image, at: todayFolderURL, filename: timeString)
                } catch {
                    print("[Screenshot] ❌ Failed to save: \(error)")
                }
            }
        } else {
            print("[Screenshot] ❌ Failed to capture screen")
        }
    }
    
    private func processOCR(for cgImage: CGImage, at folderURL: URL, filename: String) {
        print("[OCR] 🔍 Step 5: Initializing Vision OCR request")
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleOCRResult(request: request, error: error, folderURL: folderURL, filename: filename)
        }
        
        // Configure for best accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        print("[OCR] 🔍 Step 6: OCR configured (accurate mode, language correction enabled)")
        
        // Process the image
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .utility).async {
            do {
                print("[OCR] 🔍 Step 7: Performing OCR analysis...")
                let startTime = Date()
                try handler.perform([request])
                let elapsed = Date().timeIntervalSince(startTime)
                print("[OCR] 🔍 Step 8: OCR completed in \(String(format: "%.2f", elapsed)) seconds")
            } catch {
                print("[OCR] ❌ Processing failed: \(error)")
            }
        }
    }
    
    private func handleOCRResult(request: VNRequest, error: Error?, folderURL: URL, filename: String) {
        guard error == nil else {
            print("[OCR] ❌ Request failed: \(error!)")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            print("[OCR] ⚠️ No text observations found")
            return
        }
        
        print("[OCR] 🔍 Step 9: Found \(observations.count) text observations")
        
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
        
        print("[OCR] 🔍 Step 10: Extracted \(spatialTexts.count) text elements")
        if !debugTexts.isEmpty {
            print("[OCR] 🔍 Sample text: \(debugTexts.joined(separator: ", "))")
        }
        
        // Create LLM-optimized markdown content
        print("[OCR] 📝 Step 11: Creating markdown with \(spatialTexts.count) text elements")
        let markdownContent = createOptimizedMarkdownContent(
            spatialTexts: spatialTexts,
            timestamp: filename
        )
        
        // Save markdown file
        let markdownFilename = "screenshot-\(filename).md"
        let markdownURL = folderURL.appendingPathComponent(markdownFilename)
        
        do {
            try markdownContent.write(to: markdownURL, atomically: true, encoding: .utf8)
            print("[OCR] 📝 Step 12: Markdown saved: \(markdownFilename)")
            print("[OCR] 📝 File size: \(markdownContent.count) characters")
            
            // Store the OCR text for potential LLM analysis
            DispatchQueue.main.async { [weak self] in
                let ocrText = spatialTexts.map { $0.text }.joined(separator: " ")
                self?.lastOCRText = ocrText
                print("[OCR] 💾 Step 13: OCR text stored for LLM (\(ocrText.prefix(100))...)")
                
                // Trigger LLM analysis if manager is available
                if let llmManager = self?.llmAnalysisManager {
                    print("[AI] 🤖 Step 14: Triggering AI analysis pipeline...")
                    self?.triggerLLMAnalysis(ocrText: ocrText, with: llmManager)
                }
            }
        } catch {
            print("[OCR] ❌ Failed to save markdown: \(error)")
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
    private func triggerLLMAnalysis(ocrText: String, with llmManager: LLMAnalysisManager) {
        // Get current app context (simplified for demo)
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        
        print("[AI] 🤖 Step 15: Preparing to analyze activity from: \(appName)")
        print("[AI] 🤖 OCR text length: \(ocrText.count) characters")
        
        // Check if server is ready
        if !llmManager.isServerReady {
            print("[AI] ⏳ LLM server not ready yet, queuing analysis...")
            pendingAnalyses.append(PendingAnalysis(
                ocrText: ocrText,
                appName: appName,
                timestamp: Date()
            ))
            print("[AI] 📦 Analysis queued (\(pendingAnalyses.count) in queue)")
            return
        }
        
        Task {
            do {
                print("[AI] 🤖 Step 16: Sending to LLM server...")
                let result = try await llmManager.analyzeScreenshot(
                    ocrText: ocrText,
                    appName: appName,
                    windowTitle: nil
                )
                
                print("[AI] ✅ Step 17: Analysis complete!")
                print("[AI] \(result.is_valid ? "✅" : "❌") Valid: \(result.is_valid)")
                print("[AI] 📊 Activity: \(result.detected_activity)")
                print("[AI] 💭 Reason: \(result.explanation)")
                print("[AI] 🎯 Confidence: \(Int(result.confidence * 100))%")
                
            } catch {
                print("[AI] ❌ Analysis failed: \(error)")
                
                // If it failed due to server not running, queue it
                if case LLMAnalysisError.serverNotRunning = error {
                    print("[AI] 📦 Queuing analysis for retry...")
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