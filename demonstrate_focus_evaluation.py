#!/usr/bin/env python3
"""
Demonstrate the New Focus-Based Evaluation System
Shows how we test classification accuracy and confidence reliability
"""

import asyncio
import json
from typing import Tuple

# Example test scenarios to demonstrate
DEMO_SCENARIOS = [
    {
        "name": "Clear Focus Match",
        "user_focus": "Studying Computer Science", 
        "screen": "File  Edit  Debug\nclass BinaryTree:\n    def __init__(self)...",
        "app": "VS Code",
        "expected": "focused",
        "explanation": "User wants to study CS and is coding = FOCUSED"
    },
    {
        "name": "Clear Distraction",
        "user_focus": "Studying Computer Science",
        "screen": "YouTube - Funny Cat Videos\n10M views",
        "app": "YouTube", 
        "expected": "not_focused",
        "explanation": "User wants to study CS but watching YouTube = NOT FOCUSED"
    },
    {
        "name": "Ambiguous Case",
        "user_focus": "Working on Project",
        "screen": "Slack - Team discussing project deadline",
        "app": "Slack",
        "expected": "focused",
        "explanation": "Work-related Slack could be part of project = FOCUSED (but lower confidence)"
    }
]

def explain_evaluation_system():
    """Explain what we're testing"""
    print("=" * 70)
    print("🎯 NEW FOCUS-BASED EVALUATION SYSTEM")
    print("=" * 70)
    print("\nWe now test TWO specific things:\n")
    
    print("1️⃣  CLASSIFICATION ACCURACY")
    print("   Can the model correctly identify if the user is FOCUSED or NOT FOCUSED?")
    print("   - Compare user's stated goal vs what's on screen")
    print("   - Binary classification: focused or not_focused")
    print()
    
    print("2️⃣  CONFIDENCE RELIABILITY") 
    print("   Is the model's confidence score well-calibrated?")
    print("   - High confidence (>0.8) when correct = GOOD ✅")
    print("   - Low confidence (<0.5) when wrong = GOOD ✅")
    print("   - High confidence when wrong = BAD ❌")
    print("   - Low confidence when correct = BAD ❌")
    print()
    
    print("SCORING FORMULA:")
    print("  Final Score = (60% × Classification Accuracy) + (40% × Confidence Calibration)")
    print()

def show_example_scenarios():
    """Show example test scenarios"""
    print("📋 EXAMPLE TEST SCENARIOS:")
    print("-" * 70)
    
    for i, scenario in enumerate(DEMO_SCENARIOS, 1):
        print(f"\nScenario {i}: {scenario['name']}")
        print(f"  User Goal: '{scenario['user_focus']}'")
        print(f"  On Screen: {scenario['app']} - \"{scenario['screen'][:40]}...\"")
        print(f"  Expected: {scenario['expected'].upper()}")
        print(f"  Why: {scenario['explanation']}")

def simulate_model_response(scenario: dict) -> Tuple[str, float]:
    """Simulate what a good model should return"""
    # A well-calibrated model would:
    if scenario["name"] == "Clear Focus Match":
        return "focused", 0.92  # High confidence, correct
    elif scenario["name"] == "Clear Distraction":
        return "not_focused", 0.88  # High confidence, correct  
    else:  # Ambiguous
        return "focused", 0.61  # Lower confidence for ambiguous case

def demonstrate_scoring():
    """Show how we score the model"""
    print("\n\n🧮 SCORING DEMONSTRATION:")
    print("=" * 70)
    
    # Simulate test results
    print("\nSimulated Test Results:")
    print("-" * 70)
    
    correct_count = 0
    confidence_scores = []
    
    for scenario in DEMO_SCENARIOS:
        predicted, confidence = simulate_model_response(scenario)
        correct = predicted == scenario["expected"]
        
        if correct:
            correct_count += 1
            confidence_quality = confidence  # High confidence when right is good
            symbol = "✅"
        else:
            confidence_quality = 1 - confidence  # Low confidence when wrong is good
            symbol = "❌"
        
        confidence_scores.append(confidence_quality)
        
        print(f"\n{scenario['name']}:")
        print(f"  Predicted: {predicted}, Confidence: {confidence:.2f}")
        print(f"  Correct: {symbol}")
        print(f"  Confidence Quality: {confidence_quality:.2f} {'(Good)' if confidence_quality > 0.7 else '(Poor)'}")
    
    # Calculate final scores
    classification_accuracy = correct_count / len(DEMO_SCENARIOS)
    avg_confidence_quality = sum(confidence_scores) / len(confidence_scores)
    final_score = (classification_accuracy * 0.6 + avg_confidence_quality * 0.4) * 100
    
    print("\n" + "=" * 70)
    print("📊 FINAL EVALUATION:")
    print(f"  Classification Accuracy: {classification_accuracy:.1%} ({correct_count}/{len(DEMO_SCENARIOS)})")
    print(f"  Confidence Calibration: {avg_confidence_quality:.1%}")
    print(f"  🏆 FINAL SCORE: {final_score:.1f}/100")
    
    if final_score >= 80:
        print("\n✅ EXCELLENT - Model has good focus detection and confidence calibration!")
    elif final_score >= 60:
        print("\n⚠️  GOOD - But could improve confidence calibration")
    else:
        print("\n❌ NEEDS IMPROVEMENT - Poor classification or confidence")

def show_test_data_structure():
    """Show the structure of our test data"""
    print("\n\n📁 TEST DATA STRUCTURE:")
    print("=" * 70)
    print("\nEach test case contains:")
    print("""
{
    "user_focus": "What the user says they're doing",
    "screen_content": "OCR text from the screenshot", 
    "app_name": "Current application",
    "window_title": "Window title",
    "expected_classification": "focused" or "not_focused",
    "reasoning": "Why we expect this classification"
}
""")
    
    print("\nWe have 33+ predefined test scenarios covering:")
    print("  • 5 clearly focused scenarios")
    print("  • 5 clearly not focused scenarios") 
    print("  • 3 ambiguous edge cases")
    print("  • 20 additional synthetic scenarios")
    print("\nAll test data is in: focused_evaluation.py")

def main():
    """Run the demonstration"""
    print("\n🚀 FOCUS EVALUATION SYSTEM DEMONSTRATION\n")
    
    # 1. Explain the system
    explain_evaluation_system()
    
    # 2. Show example scenarios
    show_example_scenarios()
    
    # 3. Demonstrate scoring
    demonstrate_scoring()
    
    # 4. Show test data structure
    show_test_data_structure()
    
    print("\n\n✅ To run the actual evaluation:")
    print("   1. Start the mock server: python3 focused_mock_server.py")
    print("   2. Run evaluation: python3 focused_evaluation.py")
    print("\nThe evaluation will test 33+ scenarios and generate a detailed report.")

if __name__ == "__main__":
    main()