//
//  SampleGroundTruthData.swift
//  shoulder
//
//  Created by Claude Code on 9/3/25.
//

import Foundation

struct SampleDataGenerator {
    static func createSampleGroundTruthData() -> [GroundTruthSample] {
        return [
            // Coding samples - Valid (focused on coding)
            GroundTruthSample(
                ocrText: "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        VStack {\n            Text(\"Hello, World!\")\n        }\n    }\n}",
                appName: "Xcode",
                windowTitle: "ContentView.swift",
                userFocus: "Developing my iOS application",
                isValid: true,
                confidence: 1.0,
                focusArea: "coding",
                notes: "Clear coding activity in Xcode with Swift code"
            ),
            
            GroundTruthSample(
                ocrText: "class TodoItem {\n    private var title: String\n    private var isCompleted: Bool\n    \n    init(title: String) {\n        self.title = title\n        self.isCompleted = false\n    }\n    \n    func toggleComplete() {\n        isCompleted.toggle()\n    }\n}",
                appName: "Visual Studio Code",
                windowTitle: "TodoItem.swift - shoulder",
                userFocus: "Writing Swift code for my todo app",
                isValid: true,
                confidence: 1.0,
                focusArea: "coding",
                notes: "Swift class definition, clearly related to coding focus"
            ),
            
            GroundTruthSample(
                ocrText: "git add .\ngit commit -m \"Add user authentication\"\ngit push origin feature/auth",
                appName: "Terminal",
                windowTitle: "zsh",
                userFocus: "Working on my iOS project",
                isValid: true,
                confidence: 0.9,
                focusArea: "coding",
                notes: "Git commands for version control, part of development workflow"
            ),
            
            // Coding samples - Invalid (distracted from coding)
            GroundTruthSample(
                ocrText: "Check out this amazing cat video! 😂 So funny how cats react to cucumbers. Have you seen the one where...",
                appName: "Safari",
                windowTitle: "Funny Cat Videos - YouTube",
                userFocus: "Developing my iOS application",
                isValid: false,
                confidence: 1.0,
                focusArea: "coding",
                notes: "Entertainment content, not related to iOS development"
            ),
            
            GroundTruthSample(
                ocrText: "Breaking News: Tech Stock Market Update\nApple Inc. shares rose 3% today following the announcement of new iPhone features...",
                appName: "Safari",
                windowTitle: "Tech News - CNN",
                userFocus: "Working on Swift programming",
                isValid: false,
                confidence: 0.9,
                focusArea: "coding",
                notes: "News reading, not directly related to programming task"
            ),
            
            // Writing samples - Valid (focused on writing)
            GroundTruthSample(
                ocrText: "Chapter 3: The Implementation\n\nIn this chapter, we will explore the various approaches to implementing machine learning models in Swift. The first consideration is data preprocessing, which involves cleaning and transforming raw data into a format suitable for training.",
                appName: "Pages",
                windowTitle: "ML Guide - Chapter 3.pages",
                userFocus: "Writing a technical book about machine learning",
                isValid: true,
                confidence: 1.0,
                focusArea: "writing",
                notes: "Technical writing directly related to ML book project"
            ),
            
            GroundTruthSample(
                ocrText: "Blog Post: Getting Started with SwiftUI\n\nSwiftUI represents a paradigm shift in iOS development. Unlike UIKit, which relies on imperative programming patterns, SwiftUI embraces declarative syntax that makes UI code more readable and maintainable.",
                appName: "Notion",
                windowTitle: "Blog Posts - Notion",
                userFocus: "Writing blog posts about iOS development",
                isValid: true,
                confidence: 1.0,
                focusArea: "writing",
                notes: "Blog post writing about iOS development, matches focus"
            ),
            
            // Writing samples - Invalid (distracted from writing)
            GroundTruthSample(
                ocrText: "Hey! Want to grab lunch today? There's this new sushi place downtown that got great reviews. Let me know if you're interested!",
                appName: "Messages",
                windowTitle: "Messages",
                userFocus: "Writing my research paper on AI",
                isValid: false,
                confidence: 1.0,
                focusArea: "writing",
                notes: "Personal messaging, not related to research paper writing"
            ),
            
            // Research samples - Valid (focused on research)
            GroundTruthSample(
                ocrText: "Swift Documentation - Optional Binding\n\nUse optional binding to find out whether an optional contains a value, and if so, to make that value available as a temporary constant or variable. Optional binding can be used with if and while statements to check for a value inside an optional.",
                appName: "Safari",
                windowTitle: "Swift.org - The Swift Programming Language",
                userFocus: "Learning Swift programming language",
                isValid: true,
                confidence: 1.0,
                focusArea: "research",
                notes: "Reading official Swift documentation for learning"
            ),
            
            GroundTruthSample(
                ocrText: "Stack Overflow - How to implement Core Data in SwiftUI?\n\nAnswers:\n1. First, create your Core Data model...\n2. Set up the persistent container in your App file...\n3. Use @FetchRequest in your SwiftUI views...",
                appName: "Chrome",
                windowTitle: "Core Data SwiftUI - Stack Overflow",
                userFocus: "Learning iOS app development",
                isValid: true,
                confidence: 0.9,
                focusArea: "research",
                notes: "Technical research on Stack Overflow for iOS development"
            ),
            
            // Research samples - Invalid (distracted from research)
            GroundTruthSample(
                ocrText: "Best Restaurants in San Francisco 2024\n1. The French Laundry - Michelin 3-star fine dining\n2. Gary Danko - Contemporary American cuisine\n3. Benu - Modern Asian fusion...",
                appName: "Safari",
                windowTitle: "SF Restaurant Guide - Yelp",
                userFocus: "Researching machine learning algorithms",
                isValid: false,
                confidence: 1.0,
                focusArea: "research",
                notes: "Restaurant browsing, unrelated to ML research"
            ),
            
            // Communication samples - Valid (work-related communication)
            GroundTruthSample(
                ocrText: "Hi team,\n\nI've finished the user authentication module. The PR is ready for review: #156\n\nKey changes:\n- Added OAuth 2.0 support\n- Implemented secure token storage\n- Updated login flow\n\nLet me know if you have any questions!",
                appName: "Slack",
                windowTitle: "#ios-dev - shoulder",
                userFocus: "Collaborating on iOS development project",
                isValid: true,
                confidence: 1.0,
                focusArea: "communication",
                notes: "Work-related team communication about development progress"
            ),
            
            // Communication samples - Invalid (personal communication)
            GroundTruthSample(
                ocrText: "What are your weekend plans? I'm thinking of going hiking if the weather is nice. Maybe check out that new trail we talked about?",
                appName: "Slack",
                windowTitle: "#random - shoulder",
                userFocus: "Working on quarterly business report",
                isValid: false,
                confidence: 1.0,
                focusArea: "communication",
                notes: "Personal conversation, not related to business report"
            ),
            
            // Edge cases - Ambiguous scenarios
            GroundTruthSample(
                ocrText: "GitHub - MLX Swift Examples\n\nThis repository contains Swift examples for Apple's MLX framework:\n- Image classification with ResNet\n- Natural language processing with transformers\n- Custom model training examples",
                appName: "Safari",
                windowTitle: "mlx-swift-examples - GitHub",
                userFocus: "Learning machine learning",
                isValid: true,
                confidence: 0.8,
                focusArea: "research",
                notes: "GitHub repository browsing for ML learning - relevant but borderline"
            ),
            
            GroundTruthSample(
                ocrText: "Swift Package Manager Error:\nThe package dependency graph could not be resolved. Package 'MLX' requires a minimum Swift version of 5.9, but you are using Swift 5.8.",
                appName: "Xcode",
                windowTitle: "shoulder - Xcode",
                userFocus: "Building my iOS app",
                isValid: true,
                confidence: 0.9,
                focusArea: "coding",
                notes: "Error resolution is part of development process"
            ),
            
            // Low OCR confidence samples
            GroundTruthSample(
                ocrText: "func calc Tot4l() -> D0ub1e {\n    return pr1ce * qu4nt1ty\n}",
                appName: "Xcode",
                windowTitle: "Calculator.swift",
                userFocus: "Writing Swift code",
                isValid: true,
                confidence: 0.7,
                focusArea: "coding",
                ocrConfidence: 0.3,
                notes: "Poor OCR quality but still recognizable as Swift code"
            ),
            
            GroundTruthSample(
                ocrText: "Th1s 1s 4 bl0g p0st ab0ut c0d1ng b3st pr4ct1c3s...",
                appName: "Medium",
                windowTitle: "Coding Best Practices",
                userFocus: "Learning programming",
                isValid: true,
                confidence: 0.6,
                focusArea: "research",
                ocrConfidence: 0.2,
                notes: "Very poor OCR but content seems relevant to programming learning"
            ),
            
            // Temporal consistency test samples (same app, consecutive time)
            GroundTruthSample(
                id: "temporal_1",
                ocrText: "class NetworkManager {\n    private let session = URLSession.shared\n    \n    func fetchData() async throws -> Data {",
                appName: "Xcode",
                windowTitle: "NetworkManager.swift",
                userFocus: "Building networking layer for iOS app",
                isValid: true,
                confidence: 1.0,
                focusArea: "coding",
                annotationDate: Date(),
                notes: "First of temporal sequence"
            ),
            
            GroundTruthSample(
                id: "temporal_2",
                ocrText: "        let url = URL(string: endpoint)!\n        let (data, _) = try await session.data(from: url)\n        return data\n    }\n}",
                appName: "Xcode",
                windowTitle: "NetworkManager.swift",
                userFocus: "Building networking layer for iOS app",
                isValid: true,
                confidence: 1.0,
                focusArea: "coding",
                annotationDate: Date().addingTimeInterval(30), // 30 seconds later
                notes: "Continuation of same coding session"
            )
        ]
    }
    
    static func saveToFileSystem() async throws {
        let samples = createSampleGroundTruthData()
        let dataset = GroundTruthDataset()
        
        try dataset.saveSamples(samples, filename: "sample_ground_truth_data.json")
        print("✅ Saved \(samples.count) sample ground truth entries")
        
        // Also save individual samples for testing
        for (index, sample) in samples.enumerated() {
            try dataset.saveSample(sample)
        }
        
        print("📊 Sample dataset statistics:")
        let stats = try await dataset.getDatasetStatistics()
        print("- Total samples: \(stats.totalSamples)")
        print("- Valid samples: \(stats.validSamples)")
        print("- Invalid samples: \(stats.invalidSamples)")
        print("- Class balance: \(String(format: "%.2f", stats.classBalance))")
        print("- Focus areas: \(stats.focusAreaDistribution.keys.sorted().joined(separator: ", "))")
    }
}