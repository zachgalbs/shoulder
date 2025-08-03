//
//  ScreenshotManager.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/3/25.
//

import Foundation
import AppKit
import ScreenCaptureKit

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
                } catch {
                    print("Failed to save screenshot: \(error)")
                }
            }
        } else {
            print("Failed to capture screenshot")
        }
    }
}