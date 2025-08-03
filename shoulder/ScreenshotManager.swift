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

class ScreenshotManager: ObservableObject {
    private var timer: Timer?
    private let captureInterval: TimeInterval = 60.0 // 1 minute
    private var baseDirectoryURL: URL?
    
    init() {
        setupDirectories()
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
            print("Screenshot directory not available")
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
            print("Failed to create today's folder: \(error)")
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
                    print("Screenshot saved: \(filename)")
                    
                    // Process OCR asynchronously
                    processOCR(for: image, at: todayFolderURL, filename: timeString)
                } catch {
                    print("Failed to save screenshot: \(error)")
                }
            }
        } else {
            print("Failed to capture screenshot")
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
                print("OCR processing failed: \(error)")
            }
        }
    }
    
    private func handleOCRResult(request: VNRequest, error: Error?, folderURL: URL, filename: String) {
        guard error == nil else {
            print("OCR request failed: \(error!)")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            print("No text observations found")
            return
        }
        
        // Extract text and confidence scores
        var extractedText: [String] = []
        var confidenceScores: [Float] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            extractedText.append(topCandidate.string)
            confidenceScores.append(topCandidate.confidence)
        }
        
        // Create markdown content
        let markdownContent = createMarkdownContent(
            text: extractedText,
            confidenceScores: confidenceScores,
            timestamp: filename
        )
        
        // Save markdown file
        let markdownFilename = "screenshot-\(filename).md"
        let markdownURL = folderURL.appendingPathComponent(markdownFilename)
        
        do {
            try markdownContent.write(to: markdownURL, atomically: true, encoding: .utf8)
            print("OCR text saved: \(markdownFilename)")
        } catch {
            print("Failed to save OCR text: \(error)")
        }
    }
    
    private func createMarkdownContent(text: [String], confidenceScores: [Float], timestamp: String) -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var markdown = """
        # Screenshot OCR - \(timestamp)
        
        **Captured:** \(formatter.string(from: date))
        **Text Blocks Found:** \(text.count)
        **Average Confidence:** \(String(format: "%.2f", confidenceScores.isEmpty ? 0.0 : confidenceScores.reduce(0, +) / Float(confidenceScores.count)))
        
        ---
        
        ## Extracted Text
        
        """
        
        if text.isEmpty {
            markdown += "_No text found in screenshot_\n"
        } else {
            for (index, textBlock) in text.enumerated() {
                let confidence = confidenceScores.indices.contains(index) ? confidenceScores[index] : 0.0
                markdown += """
                ### Block \(index + 1) (Confidence: \(String(format: "%.2f", confidence)))
                
                \(textBlock)
                
                """
            }
        }
        
        return markdown
    }
}