#!/usr/bin/env python3
"""
Focused Evaluation Framework for LLM Classification
Tests whether the model correctly identifies if user is "focused" based on their stated goal
and current screen content, plus evaluates confidence reliability.
"""

import asyncio
import json
import statistics
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import random

import httpx
import numpy as np

# Test scenarios with user focus and screen content
FOCUS_TEST_SCENARIOS = [
    # Clearly FOCUSED scenarios (user goal matches screen content)
    {
        "user_focus": "Studying Computer Science",
        "screen_content": "File  Edit  View  Search  Terminal  Debug  Help\nclass BinaryTree:\n    def __init__(self, value):\n        self.value = value\n        self.left = None\n        self.right = None\n\n    def insert(self, value):\n        if value < self.value:\n            if self.left is None:\n                self.left = BinaryTree(value)",
        "app_name": "Visual Studio Code",
        "window_title": "data_structures.py",
        "expected_classification": "focused",
        "reasoning": "Studying CS and coding data structures = clearly focused"
    },
    {
        "user_focus": "Writing Email to Client",
        "screen_content": "To: client@company.com\nSubject: Project Update - Q4 Deliverables\n\nDear Sarah,\n\nI wanted to provide you with an update on the project milestones:\n\n1. Phase 1 completed on schedule\n2. Phase 2 in progress (75% complete)\n3. Expected delivery by end of month\n\nBest regards,\nJohn",
        "app_name": "Mail",
        "window_title": "New Message",
        "expected_classification": "focused",
        "reasoning": "Writing email and composing client email = clearly focused"
    },
    {
        "user_focus": "Learning React Framework",
        "screen_content": "React Hooks Documentation\n\nuseState\nconst [state, setState] = useState(initialValue)\n\nuseEffect\nuseEffect(() => {\n  // Side effect logic\n  return () => {\n    // Cleanup\n  };\n}, [dependencies]);\n\nRules of Hooks:\n- Only call hooks at the top level\n- Only call hooks from React functions",
        "app_name": "Chrome",
        "window_title": "React Docs - Hooks Reference",
        "expected_classification": "focused",
        "reasoning": "Learning React and reading React docs = clearly focused"
    },
    {
        "user_focus": "Designing Mobile App UI",
        "screen_content": "Layers\n├── Navigation Bar\n│   ├── Back Button\n│   ├── Title: Profile\n│   └── Settings Icon\n├── User Avatar (120x120)\n├── Username Label\n├── Bio Text Field\n└── Tab Bar\n    ├── Home\n    ├── Search\n    ├── Profile (selected)\n    └── Settings\n\nColors: #007AFF (primary), #F2F2F7 (background)",
        "app_name": "Figma",
        "window_title": "Mobile App Design - Profile Screen",
        "expected_classification": "focused",
        "reasoning": "Designing UI and using Figma for mobile design = clearly focused"
    },
    {
        "user_focus": "Analyzing Sales Data",
        "screen_content": "Sales Dashboard - Q4 2024\n\nTotal Revenue: $2.4M (+15% YoY)\nUnits Sold: 12,847\nAverage Order Value: $186.73\n\nTop Products:\n1. Product A - $450K (18.75%)\n2. Product B - $380K (15.83%)\n3. Product C - $290K (12.08%)\n\nRegional Performance:\n- North: $980K\n- South: $620K\n- East: $540K\n- West: $260K",
        "app_name": "Excel",
        "window_title": "Q4_Sales_Analysis.xlsx",
        "expected_classification": "focused",
        "reasoning": "Analyzing sales data and viewing sales dashboard = clearly focused"
    },
    
    # Clearly NOT FOCUSED scenarios (user goal doesn't match screen)
    {
        "user_focus": "Studying Computer Science",
        "screen_content": "YouTube\n\nNow Playing: Best Funny Cat Videos Compilation 2024\n10.2M views • 2 days ago\n\n15:23 / 22:45\n\n👍 245K  👎 3.2K  Share  Download  Save\n\nComments (12,845)\nTop comment: 'The cat at 5:23 had me dying 😂'\n\nUp next:\n- Epic Fail Compilation\n- Try Not To Laugh Challenge",
        "app_name": "YouTube",
        "window_title": "Funny Cat Videos",
        "expected_classification": "not_focused",
        "reasoning": "Studying CS but watching cat videos = clearly not focused"
    },
    {
        "user_focus": "Writing Email to Client",
        "screen_content": "Twitter / X\n\n@techbro: Just shipped a huge feature! 🚀\n\n@memequeen: this meeting could have been an email fr fr\n\n@developer: JavaScript developers explaining why undefined !== null for the 1000th time\n\nTrending:\n#TechTwitter\n#RemoteWork\n#CodingMemes",
        "app_name": "Chrome",
        "window_title": "Twitter",
        "expected_classification": "not_focused",
        "reasoning": "Should be writing email but browsing Twitter = clearly not focused"
    },
    {
        "user_focus": "Learning React Framework",
        "screen_content": "Netflix\n\nContinue Watching\n\nStranger Things\nSeason 4, Episode 7\n45:23 remaining\n\nThe Office\nSeason 3, Episode 14\n18:10 remaining\n\nRecommended for You:\n- The Witcher\n- Breaking Bad\n- Friends",
        "app_name": "Netflix",
        "window_title": "Netflix - Home",
        "expected_classification": "not_focused",
        "reasoning": "Should be learning React but on Netflix = clearly not focused"
    },
    {
        "user_focus": "Designing Mobile App UI",
        "screen_content": "Reddit - r/programmerhumor\n\nHot Posts:\n\n1. 'When you fix a bug but create 3 new ones' [Image] ⬆️ 5.2k\n\n2. 'CSS is easy they said...' [Meme] ⬆️ 3.8k\n\n3. 'Me explaining to my manager why we need to refactor' ⬆️ 2.9k\n\nComments:\n- 'I feel personally attacked'\n- 'This is the way'\n- 'Story of my life lol'",
        "app_name": "Chrome",
        "window_title": "Reddit",
        "expected_classification": "not_focused",
        "reasoning": "Should be designing UI but browsing Reddit = clearly not focused"
    },
    {
        "user_focus": "Analyzing Sales Data",
        "screen_content": "WhatsApp Web\n\nFamily Group (47)\nMom: Don't forget dinner on Sunday!\nDad: Who's bringing dessert?\nSister: I can make brownies\n\nFriends (128) \nJohn: Anyone up for drinks tonight?\nSarah: I'm in! What time?\nMike: Let's do 8pm at the usual place\n\nWork Team (3)\nBoss: Great job on the presentation\nYou: Thanks! Glad it went well",
        "app_name": "WhatsApp",
        "window_title": "WhatsApp Web",
        "expected_classification": "not_focused",
        "reasoning": "Should be analyzing data but on WhatsApp = clearly not focused"
    },
    
    # Edge cases (ambiguous - could go either way)
    {
        "user_focus": "Studying Computer Science",
        "screen_content": "Stack Overflow\n\nQuestion: How does quicksort algorithm work?\n\nQuicksort is a divide-and-conquer algorithm that works by selecting a 'pivot' element and partitioning the array around it.\n\ndef quicksort(arr):\n    if len(arr) <= 1:\n        return arr\n    pivot = arr[len(arr) // 2]\n    left = [x for x in arr if x < pivot]\n    middle = [x for x in arr if x == pivot]\n    right = [x for x in arr if x > pivot]\n    return quicksort(left) + middle + quicksort(right)",
        "app_name": "Chrome",
        "window_title": "Stack Overflow - Quicksort",
        "expected_classification": "focused",
        "reasoning": "Reading about algorithms on Stack Overflow could be studying"
    },
    {
        "user_focus": "Working on Project",
        "screen_content": "Slack - #general\n\nPM: Hey team, quick update on Project Phoenix\nPM: We're moving the deadline to next Friday\nDev1: Thanks for the heads up\nDev2: Do we need to adjust the sprint?\nYou: I'll update my tasks accordingly\nPM: Let's sync in tomorrow's standup",
        "app_name": "Slack",
        "window_title": "#general",
        "expected_classification": "focused",
        "reasoning": "Work-related Slack discussion about the project"
    },
    {
        "user_focus": "Research for Assignment",
        "screen_content": "Wikipedia - Machine Learning\n\nMachine learning (ML) is a field of study in artificial intelligence concerned with the development of algorithms that improve automatically through experience.\n\nTypes of Machine Learning:\n1. Supervised Learning\n2. Unsupervised Learning  \n3. Reinforcement Learning\n\nApplications include:\n- Computer vision\n- Natural language processing\n- Recommendation systems",
        "app_name": "Safari",
        "window_title": "Wikipedia - Machine Learning",
        "expected_classification": "focused",
        "reasoning": "Wikipedia research could be for assignment"
    }
]

class FocusedEvaluator:
    """Evaluates LLM's ability to classify focus and calibrate confidence"""
    
    def __init__(self, server_url: str = "http://localhost:8765"):
        self.server_url = server_url
        self.results = []
        
    async def evaluate_single_scenario(self, scenario: Dict) -> Dict:
        """Evaluate a single test scenario"""
        start_time = time.time()
        
        try:
            # Prepare request with focus context
            request_data = {
                "text": scenario["screen_content"],
                "context": {
                    "app_name": scenario["app_name"],
                    "window_title": scenario["window_title"],
                    "duration_seconds": 120,
                    "timestamp": datetime.now().isoformat(),
                    "user_focus": scenario["user_focus"]  # Key addition: user's stated focus
                }
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.server_url}/analyze_focus",  # New endpoint for focus analysis
                    json=request_data,
                    timeout=30.0
                )
            
            if response.status_code != 200:
                return {
                    "scenario": scenario["user_focus"],
                    "success": False,
                    "error": f"HTTP {response.status_code}"
                }
            
            result = response.json()
            processing_time = (time.time() - start_time) * 1000
            
            # Evaluate the response
            classification = result.get("classification", "").lower()
            confidence = result.get("confidence", 0.5)
            
            # Check if classification is correct
            correct_classification = classification == scenario["expected_classification"]
            
            # Evaluate confidence calibration
            # Good calibration: high confidence when correct, low when incorrect
            if correct_classification:
                confidence_quality = confidence  # Higher is better when correct
            else:
                confidence_quality = 1 - confidence  # Lower is better when incorrect
            
            return {
                "scenario": f"{scenario['user_focus']} + {scenario['app_name']}",
                "success": True,
                "correct_classification": correct_classification,
                "expected": scenario["expected_classification"],
                "predicted": classification,
                "confidence": confidence,
                "confidence_quality": confidence_quality,
                "processing_time_ms": processing_time,
                "reasoning": scenario.get("reasoning", "")
            }
            
        except Exception as e:
            return {
                "scenario": scenario["user_focus"],
                "success": False,
                "error": str(e)
            }
    
    async def run_evaluation(self) -> Dict:
        """Run complete evaluation suite"""
        print("🎯 Focus Classification Evaluation")
        print("=" * 60)
        print("Testing: Classification accuracy & confidence calibration\n")
        
        # Check server health
        try:
            async with httpx.AsyncClient() as client:
                health = await client.get(f"{self.server_url}/health", timeout=5.0)
                if health.status_code != 200:
                    return {"error": "Server not healthy"}
        except:
            return {"error": "Cannot connect to server"}
        
        # Run all scenarios
        for i, scenario in enumerate(FOCUS_TEST_SCENARIOS):
            result = await self.evaluate_single_scenario(scenario)
            self.results.append(result)
            
            # Print result
            if result["success"]:
                if result["correct_classification"]:
                    symbol = "✅"
                else:
                    symbol = "❌"
                
                conf_bar = "█" * int(result["confidence"] * 10) + "░" * (10 - int(result["confidence"] * 10))
                
                print(f"{symbol} Test {i+1:2d}: {result['scenario'][:40]:<40}")
                print(f"   Expected: {result['expected']:12} | Got: {result['predicted']:12}")
                print(f"   Confidence: {conf_bar} {result['confidence']:.2f}")
                print(f"   Calibration: {'Good' if result['confidence_quality'] > 0.7 else 'Poor'}")
                print()
            else:
                print(f"❌ Test {i+1:2d}: {result['scenario'][:40]:<40} - {result['error']}")
                print()
        
        # Calculate metrics
        successful_results = [r for r in self.results if r["success"]]
        
        if not successful_results:
            return {"error": "No successful tests"}
        
        # Classification accuracy
        correct_classifications = sum(1 for r in successful_results if r["correct_classification"])
        classification_accuracy = correct_classifications / len(successful_results)
        
        # Confidence calibration metrics
        confidence_qualities = [r["confidence_quality"] for r in successful_results]
        avg_confidence_quality = np.mean(confidence_qualities)
        
        # Calculate correlation between correctness and confidence
        correctness = [1 if r["correct_classification"] else 0 for r in successful_results]
        confidences = [r["confidence"] for r in successful_results]
        
        if len(correctness) > 1:
            confidence_correlation = np.corrcoef(correctness, confidences)[0, 1]
        else:
            confidence_correlation = 0
        
        # Performance metrics
        response_times = [r["processing_time_ms"] for r in successful_results]
        avg_response_time = np.mean(response_times)
        
        # Print summary
        print("\n" + "=" * 60)
        print("📊 EVALUATION RESULTS")
        print("=" * 60)
        print(f"\nClassification Accuracy: {classification_accuracy:.1%} ({correct_classifications}/{len(successful_results)})")
        print(f"Confidence Calibration: {avg_confidence_quality:.1%}")
        print(f"Confidence Correlation: {confidence_correlation:.3f}")
        print(f"Avg Response Time: {avg_response_time:.1f}ms")
        
        # Breakdown by expected classification
        focused_results = [r for r in successful_results if r["expected"] == "focused"]
        not_focused_results = [r for r in successful_results if r["expected"] == "not_focused"]
        
        if focused_results:
            focused_accuracy = sum(1 for r in focused_results if r["correct_classification"]) / len(focused_results)
            print(f"\nFocused Detection: {focused_accuracy:.1%} ({sum(1 for r in focused_results if r['correct_classification'])}/{len(focused_results)})")
        
        if not_focused_results:
            distraction_accuracy = sum(1 for r in not_focused_results if r["correct_classification"]) / len(not_focused_results)
            print(f"Distraction Detection: {distraction_accuracy:.1%} ({sum(1 for r in not_focused_results if r['correct_classification'])}/{len(not_focused_results)})")
        
        # Final score
        final_score = (classification_accuracy * 0.6 + avg_confidence_quality * 0.4) * 100
        
        print(f"\n🏆 FINAL SCORE: {final_score:.1f}/100")
        
        if final_score >= 80:
            print("✅ Excellent focus detection!")
        elif final_score >= 60:
            print("⚠️ Good but could improve confidence calibration")
        else:
            print("❌ Needs improvement in classification or confidence")
        
        return {
            "classification_accuracy": classification_accuracy,
            "confidence_calibration": avg_confidence_quality,
            "confidence_correlation": confidence_correlation,
            "avg_response_time_ms": avg_response_time,
            "final_score": final_score,
            "total_tests": len(self.results),
            "successful_tests": len(successful_results),
            "detailed_results": self.results
        }

def generate_synthetic_focus_data(count: int = 50) -> List[Dict]:
    """Generate additional synthetic test cases"""
    
    focus_goals = [
        "Writing Code",
        "Debugging Application", 
        "Reading Documentation",
        "Attending Virtual Meeting",
        "Creating Presentation",
        "Reviewing Pull Request",
        "Writing Blog Post",
        "Learning New Framework",
        "Analyzing Metrics",
        "Planning Sprint"
    ]
    
    # Focused activities
    focused_screens = {
        "Writing Code": [
            ("VS Code", "app.js", "function handleUserLogin(email, password) {\n  const user = await User.findOne({ email });\n  if (!user) return { error: 'User not found' };"),
            ("Xcode", "ViewController.swift", "@IBAction func buttonPressed(_ sender: UIButton) {\n    performSegue(withIdentifier: 'ShowDetail', sender: self)\n}"),
            ("IntelliJ", "Main.java", "public class Main {\n    public static void main(String[] args) {\n        System.out.println('Hello World');\n    }\n}")
        ],
        "Reading Documentation": [
            ("Chrome", "MDN Web Docs", "Array.prototype.map()\nThe map() method creates a new array with the results of calling a function on every element"),
            ("Safari", "Apple Developer", "SwiftUI Views and Controls\nCreate the user interface of your app using views and controls"),
            ("Chrome", "React Docs", "Thinking in React\nReact can change how you think about the designs you look at and the apps you build")
        ]
    }
    
    # Distracting activities  
    distracting_screens = [
        ("YouTube", "Trending", "MrBeast: I Spent 50 Hours Buried Alive\n45M views • 2 days ago"),
        ("Twitter", "Home", "@elonmusk: Mars needs memes\n🚀🚀🚀\n500K likes • 50K retweets"),
        ("Instagram", "Feed", "vacation_pics: Living my best life in Bali 🏝️\n#travel #blessed"),
        ("Reddit", "r/funny", "This cat thinks he's a dog [Video]\n⬆️ 25.6k ⬇️"),
        ("TikTok", "For You", "Wait for it... 😱\n#viral #fyp #mindblown")
    ]
    
    test_cases = []
    
    for _ in range(count):
        focus = random.choice(focus_goals)
        
        # 70% chance of being focused, 30% distracted
        if random.random() < 0.7 and focus in focused_screens:
            # Focused scenario
            app, window, content = random.choice(focused_screens[focus])
            test_cases.append({
                "user_focus": focus,
                "screen_content": content,
                "app_name": app,
                "window_title": window,
                "expected_classification": "focused",
                "reasoning": f"{focus} and using appropriate tool"
            })
        else:
            # Distracted scenario
            app, window, content = random.choice(distracting_screens)
            test_cases.append({
                "user_focus": focus,
                "screen_content": content,
                "app_name": app,
                "window_title": window,
                "expected_classification": "not_focused",
                "reasoning": f"Should be {focus} but on {app}"
            })
    
    return test_cases

async def main():
    """Run the focused evaluation"""
    evaluator = FocusedEvaluator()
    
    # Add synthetic data to test scenarios
    print("Generating additional synthetic test cases...")
    synthetic = generate_synthetic_focus_data(20)
    FOCUS_TEST_SCENARIOS.extend(synthetic)
    print(f"Total test cases: {len(FOCUS_TEST_SCENARIOS)}\n")
    
    results = await evaluator.run_evaluation()
    
    # Save results
    if "error" not in results:
        report_path = Path(f"/tmp/focus_evaluation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
        with open(report_path, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\n📄 Detailed report saved to: {report_path}")

if __name__ == "__main__":
    asyncio.run(main())