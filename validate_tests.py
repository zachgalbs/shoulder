#!/usr/bin/env python3
"""
Test Validation Script - Verifies LLM Analysis Tests Are Working Correctly
"""

import json
import asyncio
import httpx
from datetime import datetime
from typing import Dict, List, Tuple
import statistics

# Test cases with known expected results
VALIDATION_TESTS = [
    {
        "name": "Programming Test",
        "text": """
        func calculateProductivity(sessions: [Item]) -> Double {
            let totalDuration = sessions.compactMap { $0.duration }.reduce(0, +)
            let productiveSessions = sessions.filter { isProductive($0) }
            return Double(productiveSessions.count) / Double(sessions.count)
        }
        """,
        "expected_category": "Programming",
        "expected_score_range": (7.0, 9.5),
        "required_keywords": ["func", "sessions", "duration"],
        "app": "Xcode",
        "window": "ContentView.swift"
    },
    {
        "name": "Communication Test",
        "text": """
        From: team@company.com
        Subject: Sprint Planning Meeting
        
        Hi everyone,
        Let's meet tomorrow at 10 AM to discuss Q4 goals.
        Please review the backlog items before the meeting.
        
        Best,
        John
        """,
        "expected_category": "Communication",
        "expected_score_range": (5.0, 7.0),
        "required_keywords": ["meeting", "team", "sprint"],
        "app": "Mail",
        "window": "Inbox"
    },
    {
        "name": "Research Test",
        "text": """
        SwiftUI NavigationStack Documentation
        
        A view that displays a root view and enables navigation.
        
        Example:
        NavigationStack {
            List(items) { item in
                NavigationLink(item.name, destination: DetailView(item))
            }
        }
        """,
        "expected_category": "Research",
        "expected_score_range": (6.5, 8.5),
        "required_keywords": ["documentation", "navigation", "swiftui"],
        "app": "Safari",
        "window": "Apple Developer"
    },
    {
        "name": "Media Test",
        "text": """
        YouTube - Now Playing
        SwiftUI Tutorial for Beginners
        1.2M views • 6 months ago
        25:43 / 45:20
        
        Comments (2,345)
        Subscribe | Like | Share
        """,
        "expected_category": "Media",
        "expected_score_range": (2.0, 4.0),
        "required_keywords": ["youtube", "playing", "video"],
        "app": "YouTube",
        "window": "Video Player"
    },
    {
        "name": "Edge Case - Empty",
        "text": "",
        "should_fail": True,
        "app": "Test",
        "window": "Empty"
    },
    {
        "name": "Edge Case - Very Short",
        "text": "Hi",
        "should_fail": True,
        "app": "Test",
        "window": "Short"
    },
    {
        "name": "Edge Case - Special Characters",
        "text": "@#$%^&*()_+-=[]{}|;':\",./<>?",
        "expected_category": "Other",
        "expected_score_range": (3.0, 7.0),
        "required_keywords": [],
        "app": "Test",
        "window": "Special"
    }
]

class TestValidator:
    def __init__(self, server_url="http://localhost:8765"):
        self.server_url = server_url
        self.results = []
        
    async def validate_single_test(self, test: Dict) -> Dict:
        """Run a single validation test"""
        try:
            request_data = {
                "text": test["text"],
                "context": {
                    "app_name": test["app"],
                    "window_title": test["window"],
                    "duration_seconds": 120,
                    "timestamp": datetime.now().isoformat()
                }
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.server_url}/analyze",
                    json=request_data,
                    timeout=10.0
                )
            
            if test.get("should_fail"):
                # This test should fail
                return {
                    "test": test["name"],
                    "passed": response.status_code != 200,
                    "reason": "Correctly rejected invalid input" if response.status_code != 200 else "Should have failed but didn't"
                }
            
            if response.status_code != 200:
                return {
                    "test": test["name"],
                    "passed": False,
                    "reason": f"HTTP {response.status_code}"
                }
            
            result = response.json()
            
            # Validate response structure
            required_fields = ["summary", "category", "productivity_score", "key_activities"]
            for field in required_fields:
                if field not in result:
                    return {
                        "test": test["name"],
                        "passed": False,
                        "reason": f"Missing field: {field}"
                    }
            
            # Validate category if expected
            if "expected_category" in test:
                category_match = result["category"] == test["expected_category"]
                if not category_match:
                    return {
                        "test": test["name"],
                        "passed": False,
                        "reason": f"Category mismatch: expected {test['expected_category']}, got {result['category']}"
                    }
            
            # Validate score range if expected
            if "expected_score_range" in test:
                min_score, max_score = test["expected_score_range"]
                score = result["productivity_score"]
                if not (min_score <= score <= max_score):
                    return {
                        "test": test["name"],
                        "passed": False,
                        "reason": f"Score {score} not in range [{min_score}, {max_score}]"
                    }
            
            # Validate keywords if required
            if "required_keywords" in test and test["required_keywords"]:
                activities = [a.lower() for a in result.get("key_activities", [])]
                text_lower = test["text"].lower()
                found_keywords = []
                
                for keyword in test["required_keywords"]:
                    if keyword.lower() in text_lower and any(keyword.lower() in activity for activity in activities):
                        found_keywords.append(keyword)
                
                keyword_coverage = len(found_keywords) / len(test["required_keywords"]) if test["required_keywords"] else 1.0
                
                if keyword_coverage < 0.3:  # At least 30% of keywords should be found
                    return {
                        "test": test["name"],
                        "passed": False,
                        "reason": f"Low keyword coverage: {keyword_coverage*100:.0f}%"
                    }
            
            return {
                "test": test["name"],
                "passed": True,
                "category": result["category"],
                "score": result["productivity_score"],
                "keywords": len(result.get("key_activities", [])),
                "processing_time": result.get("processing_time_ms", 0)
            }
            
        except Exception as e:
            should_fail = test.get("should_fail", False)
            if should_fail:
                return {
                    "test": test["name"],
                    "passed": True,
                    "reason": "Correctly failed as expected"
                }
            return {
                "test": test["name"],
                "passed": False,
                "reason": str(e)
            }
    
    async def run_validation(self) -> Dict:
        """Run all validation tests"""
        print("Starting Test Validation...")
        print("=" * 60)
        
        # Check server health first
        try:
            async with httpx.AsyncClient() as client:
                health_response = await client.get(f"{self.server_url}/health", timeout=5.0)
                if health_response.status_code == 200:
                    print("✅ Server is healthy")
                else:
                    print("❌ Server health check failed")
                    return {"error": "Server not healthy"}
        except Exception as e:
            print(f"❌ Cannot connect to server: {e}")
            return {"error": "Cannot connect to server"}
        
        # Run tests
        for test in VALIDATION_TESTS:
            result = await self.validate_single_test(test)
            self.results.append(result)
            
            # Print result
            if result["passed"]:
                print(f"✅ {test['name']:30} PASSED", end="")
                if "score" in result:
                    print(f" | Category: {result.get('category', 'N/A'):12} | Score: {result.get('score', 0):.1f}")
                else:
                    print(f" | {result.get('reason', '')}")
            else:
                print(f"❌ {test['name']:30} FAILED | {result.get('reason', 'Unknown')}")
        
        # Calculate statistics
        passed = sum(1 for r in self.results if r["passed"])
        total = len(self.results)
        
        print("\n" + "=" * 60)
        print("VALIDATION RESULTS")
        print("=" * 60)
        print(f"Tests Passed: {passed}/{total} ({passed/total*100:.1f}%)")
        
        # Group by test type
        regular_tests = [r for r in self.results if not any(t.get("should_fail") for t in VALIDATION_TESTS if t["name"] == r["test"])]
        edge_cases = [r for r in self.results if any(t.get("should_fail") for t in VALIDATION_TESTS if t["name"] == r["test"])]
        
        regular_passed = sum(1 for r in regular_tests if r["passed"])
        edge_passed = sum(1 for r in edge_cases if r["passed"])
        
        print(f"\nRegular Tests: {regular_passed}/{len(regular_tests)} passed")
        print(f"Edge Cases: {edge_passed}/{len(edge_cases)} passed")
        
        # Processing time stats for successful tests
        times = [r.get("processing_time", 0) for r in self.results if r.get("processing_time")]
        if times:
            print(f"\nPerformance:")
            print(f"  Average: {statistics.mean(times):.1f}ms")
            print(f"  Min: {min(times):.1f}ms")
            print(f"  Max: {max(times):.1f}ms")
        
        # Category accuracy
        category_tests = [r for r in self.results if "category" in r]
        if category_tests:
            categories = {}
            for r in category_tests:
                cat = r["category"]
                categories[cat] = categories.get(cat, 0) + 1
            
            print(f"\nCategories Detected:")
            for cat, count in sorted(categories.items()):
                print(f"  {cat}: {count}")
        
        return {
            "passed": passed,
            "total": total,
            "success_rate": passed/total,
            "regular_success": regular_passed/len(regular_tests) if regular_tests else 0,
            "edge_success": edge_passed/len(edge_cases) if edge_cases else 0,
            "results": self.results
        }

async def main():
    print("\n🔬 LLM Analysis Test Validation Suite")
    print("=====================================\n")
    
    validator = TestValidator()
    results = await validator.run_validation()
    
    if "error" in results:
        print(f"\n❌ Validation failed: {results['error']}")
        print("\nPlease ensure the server is running:")
        print("  cd llm_server")
        print("  python3 simple_server.py")
    else:
        # Final verdict
        print("\n" + "=" * 60)
        print("FINAL VERDICT")
        print("=" * 60)
        
        if results["success_rate"] >= 0.8:
            print("✅ TESTS ARE VALID - The evaluation system is working correctly!")
            print(f"   Success rate: {results['success_rate']*100:.1f}%")
            print(f"   Regular tests: {results['regular_success']*100:.1f}% passed")
            print(f"   Edge cases: {results['edge_success']*100:.1f}% passed")
        elif results["success_rate"] >= 0.6:
            print("⚠️  TESTS PARTIALLY VALID - Some issues detected")
            print(f"   Success rate: {results['success_rate']*100:.1f}%")
            print("   Review failed tests above for details")
        else:
            print("❌ TESTS INVALID - Significant issues detected")
            print(f"   Success rate: {results['success_rate']*100:.1f}%")
            print("   The evaluation system needs debugging")
        
        # Save detailed results
        with open("/tmp/test_validation_results.json", "w") as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\nDetailed results saved to: /tmp/test_validation_results.json")

if __name__ == "__main__":
    asyncio.run(main())