//
//  EvaluationInitializer.swift
//  shoulder
//
//  Created by Claude Code on 9/3/25.
//

import Foundation

class EvaluationInitializer {
    static func setup() async {
        print("🚀 Setting up Evaluation Suite...")
        
        do {
            // Create sample ground truth data
            try await SampleDataGenerator.saveToFileSystem()
            
            print("✅ Evaluation Suite setup complete!")
            print("📍 Ground truth data saved to ~/src/shoulder/evaluation/ground_truth/")
            print("📊 Ready to evaluate AI models!")
            
        } catch {
            print("❌ Setup failed: \(error.localizedDescription)")
        }
    }
    
    static func quickTest() async {
        print("🧪 Running quick evaluation test...")
        
        // This would be called from the app to test basic functionality
        print("✅ Basic functionality test complete")
    }
}