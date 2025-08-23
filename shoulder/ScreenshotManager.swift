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
import Combine
import UniformTypeIdentifiers

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

// MARK: - Configuration Management

struct ScreenshotConfiguration {
    let captureInterval: TimeInterval
    let contentChangeThreshold: Double
    let minAnalysisInterval: TimeInterval
    let maxScreenshotsWithoutAnalysis: Int
    let maxPendingAnalyses: Int
    
    static let `default` = ScreenshotConfiguration(
        captureInterval: 10.0,
        contentChangeThreshold: 0.5,  // 50% change required to trigger analysis
        minAnalysisInterval: 30.0,
        maxScreenshotsWithoutAnalysis: 30,
        maxPendingAnalyses: 50
    )
}

// MARK: - Screenshot Quality Configuration

enum ScreenshotQuality {
    case high    // 100% resolution, 95% JPEG quality (default for reliable OCR)
    case medium  // 70% resolution, 85% JPEG quality  
    case low     // 50% resolution, 75% JPEG quality
    
    var settings: (scale: CGFloat, quality: CGFloat, format: ImageFormat) {
        switch self {
        case .high: return (1.0, 0.95, .jpeg)
        case .medium: return (0.7, 0.85, .jpeg)
        case .low: return (0.5, 0.75, .jpeg)
        }
    }
}

enum ImageFormat {
    case png
    case jpeg
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }
}

// MARK: - Thread-Safe Analysis State

actor AnalysisState {
    var previousOCRText: String = ""
    var previousAppName: String = ""
    var screenshotsSinceLastAnalysis: Int = 0
    var lastAnalysisTime: Date?
    
    func updateContent(ocrText: String, appName: String) {
        previousOCRText = ocrText
        previousAppName = appName
        screenshotsSinceLastAnalysis += 1
    }
    
    func resetAnalysisCounter() {
        screenshotsSinceLastAnalysis = 0
        lastAnalysisTime = Date()
    }
    
    func getCurrentState() -> (ocrText: String, appName: String, screenshots: Int, lastTime: Date?) {
        return (previousOCRText, previousAppName, screenshotsSinceLastAnalysis, lastAnalysisTime)
    }
}

// MARK: - ScreenshotManager

class ScreenshotManager: ObservableObject {
    // Configuration
    private let config: ScreenshotConfiguration
    
    // Core properties
    private var timer: Timer?
    private var baseDirectoryURL: URL?
    private var mlxLLMManager: MLXLLMManager?
    @Published var lastOCRText: String?
    
    // ScreenCaptureKit properties
    private var contentFilter: SCContentFilter?
    private var streamConfiguration: SCStreamConfiguration?
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    
    // Quality control - default to high for reliable OCR
    private var screenshotQuality: ScreenshotQuality = .high
    
    // Thread-safe state management
    private let analysisState = AnalysisState()
    
    // Queue for pending analyses when LLM server isn't ready
    private struct PendingAnalysis {
        let ocrText: String
        let appName: String
        let timestamp: Date
    }
    private var pendingAnalyses: [PendingAnalysis] = []
    private let pendingAnalysesLock = NSLock()
    
    init(configuration: ScreenshotConfiguration = .default) {
        self.config = configuration
        setupDirectories()
        Task {
            await setupScreenCaptureKit()
        }
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
                _ = try await mlxManager.analyzeScreenshot(
                    ocrText: pending.ocrText,
                    appName: pending.appName,
                    windowTitle: nil
                )
                
                
            } catch {
                // Log failures but don't re-queue since they'll likely fail again
                print("Failed to process pending analysis for \(pending.appName): \(error)")
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
            print("Failed to create screenshots directory: \(error.localizedDescription)")
        }
    }
    
    private func setupScreenCaptureKit() async {
        // Check if ScreenCaptureKit is available (macOS 13+)
        if #unavailable(macOS 13.0) {
            print("ScreenCaptureKit requires macOS 13.0+, falling back to legacy capture")
            isConfigured = true
            return
        }
        
        do {
            // Get available content (displays and windows)
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Create filter for main display
            guard let mainDisplay = availableContent.displays.first else {
                print("No displays available for capture")
                isConfigured = true
                return
            }
            
            contentFilter = SCContentFilter(display: mainDisplay, excludingApplications: [], exceptingWindows: [])
            
            // Configure stream settings for optimal performance
            streamConfiguration = SCStreamConfiguration()
            streamConfiguration?.width = Int(mainDisplay.width)
            streamConfiguration?.height = Int(mainDisplay.height)
            streamConfiguration?.capturesAudio = false
            streamConfiguration?.showsCursor = false
            streamConfiguration?.scalesToFit = false
            
            // Configure quality based on setting
            updateConfigurationQuality()
            
            print("ScreenCaptureKit configured: \(streamConfiguration?.width ?? 0)x\(streamConfiguration?.height ?? 0)")
            
        } catch {
            print("Failed to setup ScreenCaptureKit: \(error.localizedDescription)")
        }
        
        isConfigured = true
    }
    
    private func updateConfigurationQuality() {
        guard let config = streamConfiguration else { return }
        
        // Get display dimensions from current configuration
        let baseWidth = config.width
        let baseHeight = config.height
        
        let qualitySettings = screenshotQuality.settings
        config.width = Int(CGFloat(baseWidth) * qualitySettings.scale)
        config.height = Int(CGFloat(baseHeight) * qualitySettings.scale)
    }
    
    private func waitForConfiguration() async {
        while !isConfigured {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    func setScreenshotQuality(_ quality: ScreenshotQuality) {
        guard quality != screenshotQuality else { return }
        
        screenshotQuality = quality
        print("Screenshot quality changed to: \(quality)")
        
        // Only update configuration if already set up
        if isConfigured {
            updateConfigurationQuality()
        }
    }
    
    func startCapturing() {
        guard timer == nil else { return }
        
        // Take first screenshot immediately
        captureScreenshot()
        
        // Set up timer for regular captures
        timer = Timer.scheduledTimer(withTimeInterval: config.captureInterval, repeats: true) { _ in
            self.captureScreenshot()
        }
        
    }
    
    func stopCapturing() {
        timer?.invalidate()
        timer = nil
    }
    
    private func captureScreenshot() {
        Task {
            await waitForConfiguration()
            await performScreenshotCapture()
        }
    }
    
    private func performScreenshotCapture() async {
        guard let baseURL = baseDirectoryURL else {
            print("Base directory URL not available")
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
            print("Failed to create today's directory: \(error.localizedDescription)")
            return
        }
        
        // Generate timestamp filename with appropriate extension
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let timeString = timeFormatter.string(from: Date())
        let qualitySettings = screenshotQuality.settings
        let filename = "screenshot-\(timeString).\(qualitySettings.format.fileExtension)"
        let fileURL = todayFolderURL.appendingPathComponent(filename)
        
        // Try ScreenCaptureKit first, fallback to legacy method
        if let contentFilter = contentFilter,
           let streamConfiguration = streamConfiguration {
            
            await captureWithScreenCaptureKit(contentFilter: contentFilter, 
                                            configuration: streamConfiguration, 
                                            fileURL: fileURL, 
                                            todayFolderURL: todayFolderURL, 
                                            timeString: timeString)
        } else {
            // Fallback to legacy CGDisplayCreateImage
            captureLegacyScreenshot(fileURL: fileURL, todayFolderURL: todayFolderURL, timeString: timeString)
        }
    }
    
    private func captureWithScreenCaptureKit(contentFilter: SCContentFilter, 
                                           configuration: SCStreamConfiguration, 
                                           fileURL: URL, 
                                           todayFolderURL: URL, 
                                           timeString: String) async {
        // Use continuation to convert callback to async
        await withCheckedContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter,
                                            configuration: configuration) { cgImage, error in
                if let error = error {
                    print("ScreenCaptureKit capture failed: \(error.localizedDescription), falling back to legacy")
                    // Fallback to legacy method
                    self.captureLegacyScreenshot(fileURL: fileURL, todayFolderURL: todayFolderURL, timeString: timeString)
                } else if let cgImage = cgImage {
                    // Save with quality settings
                    let qualitySettings = self.screenshotQuality.settings
                    
                    if qualitySettings.format == .jpeg {
                        self.saveImageAsJPEG(cgImage, to: fileURL, quality: qualitySettings.quality)
                    } else {
                        self.saveImageAsPNG(cgImage, to: fileURL)
                    }
                    
                    // Process OCR asynchronously
                    self.processOCR(for: cgImage, at: todayFolderURL, filename: timeString)
                }
                continuation.resume()
            }
        }
    }
    
    private func captureLegacyScreenshot(fileURL: URL, todayFolderURL: URL, timeString: String) {
        // Legacy capture using CGDisplayCreateImage
        if let displayID = CGMainDisplayID() as CGDirectDisplayID?,
           let image = CGDisplayCreateImage(displayID) {
            
            let qualitySettings = screenshotQuality.settings
            let scaledImage = createScaledImage(from: image, scale: qualitySettings.scale) ?? image
            
            if qualitySettings.format == .jpeg {
                saveImageAsJPEG(scaledImage, to: fileURL, quality: qualitySettings.quality)
            } else {
                saveImageAsPNG(scaledImage, to: fileURL)
            }
            
            // Process OCR asynchronously
            processOCR(for: scaledImage, at: todayFolderURL, filename: timeString)
        } else {
            print("Failed to capture screenshot using legacy method")
        }
    }
    
    private func createScaledImage(from cgImage: CGImage, scale: CGFloat) -> CGImage? {
        guard scale < 1.0 else { return cgImage }
        
        let newWidth = Int(CGFloat(cgImage.width) * scale)
        let newHeight = Int(CGFloat(cgImage.height) * scale)
        
        guard let context = CGContext(
            data: nil, width: newWidth, height: newHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .high  // Maintains text readability
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }
    
    private func saveImageAsJPEG(_ cgImage: CGImage, to url: URL, quality: CGFloat) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            print("Failed to create JPEG destination")
            return
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        if !CGImageDestinationFinalize(destination) {
            print("Failed to save JPEG image")
        }
    }
    
    private func saveImageAsPNG(_ cgImage: CGImage, to url: URL) {
        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        if let tiffData = nsImage.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            
            do {
                try pngData.write(to: url)
            } catch {
                print("Failed to save PNG image: \(error.localizedDescription)")
            }
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
                print("OCR processing failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleOCRResult(request: VNRequest, error: Error?, folderURL: URL, filename: String) {
        guard error == nil else {
            print("OCR request failed: \(error?.localizedDescription ?? "Unknown error")")
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
            
            // Store the OCR text and conditionally trigger LLM analysis
            DispatchQueue.main.async { [weak self] in
                let ocrText = spatialTexts.map { $0.text }.joined(separator: " ")
                let currentAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
                self?.lastOCRText = ocrText
                
                // Check if we should trigger analysis based on content changes
                guard let strongSelf = self else { return }
                
                Task {
                    let shouldAnalyze = await strongSelf.shouldTriggerAnalysis(currentOCRText: ocrText, currentAppName: currentAppName)
                    
                    if shouldAnalyze, let mlxManager = strongSelf.mlxLLMManager {
                        strongSelf.triggerMLXAnalysis(ocrText: ocrText, with: mlxManager)
                        await strongSelf.analysisState.resetAnalysisCounter()
                    }
                    
                    // Always update content history regardless of whether we analyzed
                    await strongSelf.updateContentHistory(ocrText: ocrText, appName: currentAppName)
                }
            }
        } catch {
            print("Failed to save markdown file: \(error.localizedDescription)")
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
    
    // MARK: - Content Change Detection
    
    private func calculateJaccardSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func shouldTriggerAnalysis(currentOCRText: String, currentAppName: String) async -> Bool {
        let state = await analysisState.getCurrentState()
        
        // Force analysis if app has changed (context switch detection)
        if currentAppName != state.appName && !state.appName.isEmpty {
            return true
        }
        
        // Force analysis if too many screenshots without analysis (time-based fallback)
        if state.screenshots >= config.maxScreenshotsWithoutAnalysis {
            return true
        }
        
        // Calculate similarity between current and previous OCR text
        let similarity = calculateJaccardSimilarity(currentOCRText, state.ocrText)
        let changeRatio = 1.0 - similarity
        
        // Check if enough time has passed since last analysis (prevents spam)
        let enoughTimeHasPassed = state.lastTime == nil || 
            Date().timeIntervalSince(state.lastTime!) >= config.minAnalysisInterval
        
        // Trigger analysis if significant content change AND enough time has passed
        return changeRatio > config.contentChangeThreshold && enoughTimeHasPassed
    }
    
    private func updateContentHistory(ocrText: String, appName: String) async {
        await analysisState.updateContent(ocrText: ocrText, appName: appName)
    }
    
    @MainActor
    private func triggerMLXAnalysis(ocrText: String, with mlxManager: MLXLLMManager) {
        // Get current app context (simplified for demo)
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        
        print("Triggering LLM analysis for app: \(appName)")
        
        // Check if model is ready
        if !mlxManager.isModelReady {
            print("Model not ready, queueing analysis")
            addPendingAnalysis(PendingAnalysis(
                ocrText: ocrText,
                appName: appName,
                timestamp: Date()
            ))
            return
        }
        
        Task {
            do {
                _ = try await mlxManager.analyzeScreenshot(
                    ocrText: ocrText,
                    appName: appName,
                    windowTitle: nil
                )
                
                print("Analysis completed for \(appName)")
                
            } catch {
                // Handle different error types appropriately
                switch error {
                case MLXLLMError.modelNotLoaded:
                    // Queue for retry when model is ready
                    print("Model not loaded, queueing for retry")
                    addPendingAnalysis(PendingAnalysis(
                        ocrText: ocrText,
                        appName: appName,
                        timestamp: Date()
                    ))
                case MLXLLMError.invalidResponse:
                    // Log but don't retry - LLM couldn't parse or generate valid JSON
                    print("LLM analysis failed - invalid response for \(appName)")
                default:
                    print("Analysis error for \(appName): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Bounded Queue Management
    
    private func addPendingAnalysis(_ analysis: PendingAnalysis) {
        pendingAnalysesLock.lock()
        defer { pendingAnalysesLock.unlock() }
        
        // Implement bounded queue with FIFO eviction
        if pendingAnalyses.count >= config.maxPendingAnalyses {
            pendingAnalyses.removeFirst() // Remove oldest
            print("Pending analyses queue full, removed oldest entry")
        }
        pendingAnalyses.append(analysis)
    }
    
    // MARK: - Public API for Quality Control
    
    func getCurrentQuality() -> ScreenshotQuality {
        return screenshotQuality
    }
    
    func getQualityStats() -> (width: Int, height: Int, format: String, quality: CGFloat)? {
        guard let config = streamConfiguration else { return nil }
        let settings = screenshotQuality.settings
        return (
            width: config.width,
            height: config.height,
            format: settings.format.fileExtension,
            quality: settings.quality
        )
    }
    
    func getConfiguration() -> ScreenshotConfiguration {
        return config
    }
}
