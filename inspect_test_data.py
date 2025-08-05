#!/usr/bin/env python3
"""
Inspect and Display All Test Cases
Shows exactly what we're testing and what we expect
"""

import json
from datetime import datetime

# All test cases with their inputs and expected outputs
TEST_CASES = {
    "Programming Tests": [
        {
            "input_text": """
func calculateProductivity(sessions: [Item]) -> Double {
    let totalDuration = sessions.compactMap { $0.duration }.reduce(0, +)
    let productiveSessions = sessions.filter { isProductive($0) }
    return Double(productiveSessions.count) / Double(sessions.count)
}""",
            "simulated_app": "Xcode",
            "simulated_window": "ContentView.swift",
            "expected_category": "Programming",
            "expected_score_range": "7.5 - 9.5",
            "why_this_score": "Active coding = high productivity",
            "expected_keywords": ["func", "sessions", "duration", "calculate", "reduce"]
        },
        {
            "input_text": """
class DataProcessor:
    def __init__(self, data):
        self.data = data
        self.results = []
    
    def analyze(self):
        for item in self.data:
            result = self.process_item(item)
            self.results.append(result)
        return self.results""",
            "simulated_app": "Visual Studio Code", 
            "simulated_window": "processor.py",
            "expected_category": "Programming",
            "expected_score_range": "7.5 - 9.5",
            "why_this_score": "Writing Python class = productive programming",
            "expected_keywords": ["class", "def", "data", "analyze", "process"]
        },
        {
            "input_text": """
$ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  modified:   shoulder/LLMAnalysisManager.swift
  
$ git add .
$ git commit -m "Add LLM analysis evaluation"
[main abc123] Add LLM analysis evaluation
 2 files changed, 245 insertions(+)""",
            "simulated_app": "Terminal",
            "simulated_window": "bash",
            "expected_category": "Programming",
            "expected_score_range": "7.0 - 8.5",
            "why_this_score": "Version control = productive but not direct coding",
            "expected_keywords": ["git", "commit", "branch", "modified", "changes"]
        }
    ],
    
    "Communication Tests": [
        {
            "input_text": """
From: team@company.com
Subject: Sprint Planning Meeting

Hi everyone,

Let's meet tomorrow at 10 AM to discuss Q4 goals.
Please review the backlog items before the meeting.

Agenda:
- Sprint goal definition  
- Story estimation
- Resource allocation

Best,
John""",
            "simulated_app": "Mail",
            "simulated_window": "Inbox",
            "expected_category": "Communication",
            "expected_score_range": "5.0 - 7.0",
            "why_this_score": "Work email = moderate productivity",
            "expected_keywords": ["meeting", "sprint", "team", "agenda", "goals"]
        },
        {
            "input_text": """
Slack - #engineering

Sarah: Hey team, PR #234 is ready for review
Mike: I'll take a look!
Sarah: Thanks! The main changes are in the authentication module
You: LGTM, approved ✅
Bot: Build #567 passed successfully""",
            "simulated_app": "Slack",
            "simulated_window": "#engineering",
            "expected_category": "Communication",
            "expected_score_range": "5.5 - 7.0",
            "why_this_score": "Team collaboration = moderate productivity",
            "expected_keywords": ["team", "review", "PR", "approved", "build"]
        }
    ],
    
    "Research Tests": [
        {
            "input_text": """
SwiftUI NavigationStack Documentation

A view that displays a root view and enables navigation.

Declaration:
struct NavigationStack<Data, Root> where Root : View

Overview:
Use NavigationStack to present a stack of views. Users navigate by selecting NavigationLink views.

Example:
NavigationStack {
    List(items) { item in
        NavigationLink(item.name, destination: DetailView(item))
    }
}""",
            "simulated_app": "Safari",
            "simulated_window": "Apple Developer",
            "expected_category": "Research",
            "expected_score_range": "6.5 - 8.5",
            "why_this_score": "Learning/documentation = productive research",
            "expected_keywords": ["NavigationStack", "documentation", "SwiftUI", "example", "view"]
        },
        {
            "input_text": """
Stack Overflow - How to handle async/await in Swift?

Question (234 votes):
I'm trying to understand the new async/await syntax in Swift.

Answer (456 votes):
You can use try/catch with async/await:

func fetchData() async throws -> Data {
    let url = URL(string: "https://api.example.com")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}""",
            "simulated_app": "Chrome",
            "simulated_window": "Stack Overflow",
            "expected_category": "Research",
            "expected_score_range": "7.0 - 8.5",
            "why_this_score": "Problem-solving research = productive",
            "expected_keywords": ["async", "await", "Stack Overflow", "answer", "Swift"]
        }
    ],
    
    "Media Tests": [
        {
            "input_text": """
YouTube - Now Playing
SwiftUI Tutorial for Beginners
Channel: Code Academy
1.2M views • 6 months ago

25:43 / 45:20

Comments (2,345)
Top comment: "Best SwiftUI tutorial!"

Related videos:
- Advanced SwiftUI Animations
- Building Your First iOS App

Subscribe | Like | Share""",
            "simulated_app": "YouTube",
            "simulated_window": "Video Player",
            "expected_category": "Media",
            "expected_score_range": "2.0 - 4.0",
            "why_this_score": "Video watching = low productivity (even educational)",
            "expected_keywords": ["YouTube", "video", "playing", "tutorial", "subscribe"]
        },
        {
            "input_text": """
Netflix

Now Playing: The Social Dilemma
Documentary | 2020 | 1h 34m
A look at how social media is designed to be addictive

Time: 45:23 / 1:34:00

Subtitles: English
Audio: English [Original]""",
            "simulated_app": "Netflix",
            "simulated_window": "Video Player",
            "expected_category": "Media",
            "expected_score_range": "1.0 - 3.0",
            "why_this_score": "Entertainment = very low productivity",
            "expected_keywords": ["Netflix", "playing", "documentary", "video", "watching"]
        }
    ],
    
    "System Tests": [
        {
            "input_text": """
Finder - ~/Documents/Projects/shoulder

Name                    Date Modified       Size        Kind
▼ shoulder             Today, 2:15 PM      --          Folder
  ▸ shoulder.xcodeproj Today, 2:15 PM      --          Folder
  ▸ shoulder           Today, 2:10 PM      --          Folder
    README.md          3 days ago          4 KB        Markdown
    .gitignore         1 week ago          2 KB        Text

7 items, 245.3 MB available""",
            "simulated_app": "Finder",
            "simulated_window": "shoulder",
            "expected_category": "System",
            "expected_score_range": "4.0 - 6.0",
            "why_this_score": "File management = some productivity",
            "expected_keywords": ["Finder", "folder", "Documents", "file", "items"]
        }
    ],
    
    "Edge Cases": [
        {
            "input_text": "",
            "simulated_app": "Test",
            "simulated_window": "Empty",
            "expected_behavior": "Should reject - empty text",
            "why": "No text to analyze"
        },
        {
            "input_text": "Hi",
            "simulated_app": "Test", 
            "simulated_window": "Short",
            "expected_behavior": "Should reject - too short",
            "why": "Insufficient text for meaningful analysis"
        },
        {
            "input_text": "@#$%^&*()_+-=[]{}|;':\",./<>?",
            "simulated_app": "Test",
            "simulated_window": "Special",
            "expected_category": "Other",
            "expected_score_range": "3.0 - 7.0",
            "why_this_score": "Unclear activity = neutral score",
            "expected_keywords": []
        }
    ]
}

def display_test_cases():
    """Display all test cases in a readable format"""
    
    print("=" * 80)
    print("🔍 LLM ANALYSIS TEST CASES - COMPLETE INSPECTION")
    print("=" * 80)
    print("\nThese are the EXACT inputs and expected outputs we're testing:\n")
    
    test_count = 0
    
    for category, tests in TEST_CASES.items():
        print(f"\n{'─' * 60}")
        print(f"📁 {category}")
        print(f"{'─' * 60}")
        
        for i, test in enumerate(tests, 1):
            test_count += 1
            print(f"\n🧪 Test #{test_count}: {category} - Example {i}")
            print(f"{'─' * 40}")
            
            # Input
            print("\n📥 INPUT:")
            print(f"App: {test.get('simulated_app', 'N/A')}")
            print(f"Window: {test.get('simulated_window', 'N/A')}")
            print(f"Text ({len(test.get('input_text', ''))} chars):")
            print("```")
            print(test.get('input_text', '')[:500])  # Show first 500 chars
            if len(test.get('input_text', '')) > 500:
                print("... [truncated]")
            print("```")
            
            # Expected Output
            print("\n📤 EXPECTED OUTPUT:")
            if 'expected_category' in test:
                print(f"Category: {test['expected_category']}")
                print(f"Score Range: {test.get('expected_score_range', 'N/A')}")
                print(f"Reasoning: {test.get('why_this_score', 'N/A')}")
                print(f"Keywords: {', '.join(test.get('expected_keywords', []))}")
            else:
                print(f"Behavior: {test.get('expected_behavior', 'N/A')}")
                print(f"Reasoning: {test.get('why', 'N/A')}")
            
            print()
    
    # Summary statistics
    print("\n" + "=" * 80)
    print("📊 TEST COVERAGE SUMMARY")
    print("=" * 80)
    
    print(f"\nTotal Test Cases: {test_count}")
    print("\nCategories Tested:")
    print("  • Programming: 3 tests (Swift, Python, Git)")
    print("  • Communication: 2 tests (Email, Slack)")
    print("  • Research: 2 tests (Documentation, Stack Overflow)")
    print("  • Media: 2 tests (YouTube, Netflix)")
    print("  • System: 1 test (Finder)")
    print("  • Edge Cases: 3 tests (Empty, Short, Special chars)")
    
    print("\nScore Ranges:")
    print("  • High Productivity (7.5-9.5): Programming")
    print("  • Good Productivity (6.5-8.5): Research, Documentation")
    print("  • Moderate (5.0-7.0): Communication")
    print("  • Low (2.0-4.0): Media consumption")
    print("  • Neutral (4.0-6.0): System tasks")
    
    print("\n" + "=" * 80)
    print("💡 EVALUATION CRITERIA")
    print("=" * 80)
    print("""
The test cases are designed to validate:

1. CATEGORY DETECTION
   - Can it distinguish code from emails?
   - Does it recognize documentation vs entertainment?
   
2. PRODUCTIVITY SCORING
   - Programming gets high scores (7.5-9.5)
   - Entertainment gets low scores (2.0-4.0)
   - Communication is moderate (5.0-7.0)
   
3. KEYWORD EXTRACTION
   - Finds relevant technical terms
   - Identifies activity-specific words
   
4. REAL-WORLD ACCURACY
   - Uses actual screenshots text patterns
   - Mimics real app windows and content
   - Tests common developer activities

5. EDGE CASE HANDLING
   - Rejects empty/minimal input
   - Handles special characters
   - Doesn't crash on unusual input
""")

if __name__ == "__main__":
    display_test_cases()
    
    # Save to file for inspection
    with open("/tmp/test_cases_full.json", "w") as f:
        json.dump(TEST_CASES, f, indent=2)
    
    print(f"\n📁 Full test data saved to: /tmp/test_cases_full.json")
    print("\n✅ These test cases represent realistic workplace scenarios!")