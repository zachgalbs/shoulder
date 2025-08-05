#!/usr/bin/env python3
"""
LLM Analysis Evaluation Framework
Generates synthetic data and evaluates analysis performance
"""

import asyncio
import json
import random
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import statistics

import httpx
from pydantic import BaseModel
import numpy as np

# Evaluation metrics storage
class EvaluationMetrics(BaseModel):
    total_tests: int = 0
    successful_analyses: int = 0
    failed_analyses: int = 0
    average_processing_time_ms: float = 0.0
    average_productivity_score: float = 0.0
    category_accuracy: float = 0.0
    confidence_correlation: float = 0.0
    response_times: List[float] = []
    scores_by_category: Dict[str, List[float]] = {}
    error_types: Dict[str, int] = {}

class SyntheticDataGenerator:
    """Generate realistic synthetic OCR data for testing"""
    
    # Application templates
    APP_TEMPLATES = {
        "Programming": {
            "apps": ["Visual Studio Code", "Xcode", "IntelliJ IDEA", "Terminal", "Sublime Text"],
            "keywords": ["function", "class", "import", "def", "var", "const", "return", "if", "for", "while",
                        "public", "private", "interface", "struct", "enum", "protocol", "extension"],
            "code_snippets": [
                """func calculateProductivity(sessions: [Item]) -> Double {
    let totalDuration = sessions.compactMap { $0.duration }.reduce(0, +)
    let productiveSessions = sessions.filter { isProductive($0) }
    return Double(productiveSessions.count) / Double(sessions.count)
}""",
                """class DataAnalyzer:
    def __init__(self, data):
        self.data = data
        self.results = []
    
    def analyze(self):
        for item in self.data:
            result = self.process_item(item)
            self.results.append(result)
        return self.results""",
                """const fetchUserData = async (userId) => {
    try {
        const response = await fetch(`/api/users/${userId}`);
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Failed to fetch user:', error);
        return null;
    }
};"""
            ],
            "window_titles": ["main.swift", "index.js", "DataProcessor.java", "api_handler.py", "styles.css"]
        },
        "Communication": {
            "apps": ["Slack", "Microsoft Teams", "Mail", "Messages", "Discord", "Zoom"],
            "keywords": ["meeting", "email", "message", "chat", "call", "reply", "forward", "schedule",
                        "@mention", "thread", "channel", "direct message"],
            "text_patterns": [
                "Re: Project Update - Q4 Goals",
                "Team Standup - Engineering",
                "1:1 with Manager - Performance Review",
                "Client Meeting Notes - Requirements Discussion",
                "#general - New feature announcement",
                "Direct Message with John: Code review feedback"
            ],
            "window_titles": ["Inbox", "Team Chat", "Video Call", "New Message", "Meeting Room"]
        },
        "Research": {
            "apps": ["Safari", "Chrome", "Firefox", "Documentation", "Stack Overflow"],
            "keywords": ["search", "google", "stackoverflow", "documentation", "tutorial", "guide",
                        "how to", "example", "reference", "api docs", "best practices"],
            "text_patterns": [
                "SwiftUI Navigation Best Practices - Apple Developer",
                "How to implement async/await in Python - Stack Overflow",
                "Machine Learning Tutorial - TensorFlow Documentation",
                "REST API Design Guidelines - Google Cloud",
                "React Hooks Explained - Medium Article"
            ],
            "window_titles": ["Google Search", "Documentation", "Stack Overflow", "Developer Portal", "API Reference"]
        },
        "Documentation": {
            "apps": ["Microsoft Word", "Google Docs", "Notion", "Confluence", "Pages"],
            "keywords": ["document", "report", "presentation", "slides", "notes", "outline",
                        "section", "chapter", "table of contents", "summary", "conclusion"],
            "text_patterns": [
                "Technical Specification Document\n1. Overview\n2. Architecture\n3. Implementation",
                "Q4 2024 Progress Report\nExecutive Summary\nKey Achievements",
                "Project Roadmap\n- Phase 1: Planning\n- Phase 2: Development\n- Phase 3: Testing",
                "Meeting Notes - Sprint Planning\nAction Items:\n• Update dependencies\n• Fix critical bugs"
            ],
            "window_titles": ["Project Plan.docx", "Technical Spec", "Meeting Notes", "Report Draft", "Presentation.pptx"]
        },
        "Design": {
            "apps": ["Figma", "Sketch", "Adobe Photoshop", "Affinity Designer", "Canva"],
            "keywords": ["design", "layout", "color", "typography", "component", "layer", "frame",
                        "prototype", "wireframe", "mockup", "pixel", "vector"],
            "text_patterns": [
                "Dashboard Layout - Main View\nComponents: Navigation, Charts, Stats",
                "Color Palette: Primary #007AFF, Secondary #34C759",
                "Typography: SF Pro Display - Headers, SF Pro Text - Body",
                "Component Library - Button States: Default, Hover, Active, Disabled"
            ],
            "window_titles": ["Design System", "App Mockup", "Icon Set", "Prototype v2", "Style Guide"]
        },
        "Media": {
            "apps": ["YouTube", "Netflix", "Spotify", "Apple Music", "VLC"],
            "keywords": ["video", "music", "playlist", "episode", "season", "track", "album",
                        "streaming", "playback", "pause", "skip"],
            "text_patterns": [
                "Now Playing: Coding Focus Playlist",
                "YouTube - Programming Tutorial: Advanced Swift Patterns",
                "Podcast: The Daily - Tech News Roundup",
                "Netflix - Documentary: The Social Dilemma"
            ],
            "window_titles": ["Video Player", "Music Library", "Playlist", "Now Playing", "Media Controls"]
        },
        "System": {
            "apps": ["Finder", "System Preferences", "Activity Monitor", "Terminal", "Console"],
            "keywords": ["file", "folder", "directory", "settings", "preferences", "cpu", "memory",
                        "process", "disk", "network", "permissions"],
            "text_patterns": [
                "~/Documents/Projects/shoulder/src",
                "System Preferences > Security & Privacy > Privacy",
                "Activity Monitor - CPU Usage: 45%, Memory: 8.2GB",
                "Terminal - git status\nOn branch main\nYour branch is up to date"
            ],
            "window_titles": ["Finder", "System Settings", "Activity Monitor", "Terminal", "Disk Utility"]
        },
        "Other": {
            "apps": ["Generic App", "Unknown", "Miscellaneous"],
            "keywords": ["general", "misc", "other", "activity", "task"],
            "text_patterns": [
                "General application content",
                "Miscellaneous text and data",
                "Unknown activity"
            ],
            "window_titles": ["Untitled", "New Document", "Window", "Application"]
        }
    }
    
    @classmethod
    def generate_ocr_text(cls, category: str, complexity: str = "medium") -> Tuple[str, Dict]:
        """Generate synthetic OCR text for a given category"""
        template = cls.APP_TEMPLATES.get(category, cls.APP_TEMPLATES["Other"])
        
        # Select random app
        app_name = random.choice(template.get("apps", ["Generic App"]))
        window_title = random.choice(template.get("window_titles", ["Untitled"]))
        
        # Build text based on complexity
        text_parts = []
        
        if complexity == "simple":
            # Just keywords
            keywords = random.sample(template.get("keywords", []), min(5, len(template.get("keywords", []))))
            text_parts.append(" ".join(keywords))
        
        elif complexity == "medium":
            # Mix of patterns and keywords
            if "text_patterns" in template:
                text_parts.append(random.choice(template["text_patterns"]))
            keywords = random.sample(template.get("keywords", []), min(8, len(template.get("keywords", []))))
            text_parts.append(" ".join(keywords))
        
        else:  # complex
            # Full snippets
            if "code_snippets" in template:
                text_parts.append(random.choice(template["code_snippets"]))
            elif "text_patterns" in template:
                text_parts.extend(random.sample(template["text_patterns"], 
                                               min(3, len(template["text_patterns"]))))
            keywords = random.sample(template.get("keywords", []), min(10, len(template.get("keywords", []))))
            text_parts.append(" ".join(keywords))
        
        # Add some noise
        if random.random() < 0.3:
            text_parts.append(f"Time: {datetime.now().strftime('%H:%M')}")
            text_parts.append(f"File: {window_title}")
        
        ocr_text = "\n\n".join(text_parts)
        
        # Generate expected values
        expected = {
            "category": category,
            "min_productivity_score": cls._get_expected_score_range(category)[0],
            "max_productivity_score": cls._get_expected_score_range(category)[1],
            "expected_keywords": template.get("keywords", [])[:5]
        }
        
        metadata = {
            "app_name": app_name,
            "window_title": window_title,
            "duration_seconds": random.randint(30, 600),
            "complexity": complexity
        }
        
        return ocr_text, expected, metadata
    
    @staticmethod
    def _get_expected_score_range(category: str) -> Tuple[float, float]:
        """Get expected productivity score range for category"""
        ranges = {
            "Programming": (7.0, 9.5),
            "Documentation": (6.5, 8.5),
            "Research": (6.0, 8.0),
            "Design": (7.0, 9.0),
            "Communication": (5.0, 7.0),
            "Media": (2.0, 4.0),
            "System": (4.0, 6.0),
            "Other": (3.0, 7.0)
        }
        return ranges.get(category, (3.0, 7.0))
    
    @classmethod
    def generate_test_suite(cls, num_samples: int = 50) -> List[Dict]:
        """Generate a complete test suite with various scenarios"""
        test_cases = []
        
        categories = list(cls.APP_TEMPLATES.keys())
        complexities = ["simple", "medium", "complex"]
        
        for i in range(num_samples):
            category = random.choice(categories)
            complexity = random.choice(complexities)
            
            ocr_text, expected, metadata = cls.generate_ocr_text(category, complexity)
            
            test_case = {
                "id": f"test_{i:04d}",
                "ocr_text": ocr_text,
                "expected": expected,
                "metadata": metadata,
                "timestamp": datetime.now().isoformat()
            }
            
            test_cases.append(test_case)
        
        return test_cases

class LLMAnalysisEvaluator:
    """Evaluate LLM analysis performance"""
    
    def __init__(self, server_url: str = "http://localhost:8765"):
        self.server_url = server_url
        self.metrics = EvaluationMetrics()
        self.test_results = []
    
    async def evaluate_single(self, test_case: Dict) -> Dict:
        """Evaluate a single test case"""
        start_time = time.time()
        
        try:
            # Prepare request
            request_data = {
                "text": test_case["ocr_text"],
                "context": {
                    "app_name": test_case["metadata"]["app_name"],
                    "window_title": test_case["metadata"]["window_title"],
                    "duration_seconds": test_case["metadata"]["duration_seconds"],
                    "timestamp": datetime.now().isoformat()
                },
                "model": "dolphin-mistral:latest"
            }
            
            # Send request
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.server_url}/analyze",
                    json=request_data,
                    timeout=30.0
                )
            
            if response.status_code == 200:
                result = response.json()
                processing_time = (time.time() - start_time) * 1000
                
                # Evaluate results
                evaluation = self._evaluate_result(result, test_case["expected"])
                
                return {
                    "test_id": test_case["id"],
                    "success": True,
                    "processing_time_ms": processing_time,
                    "result": result,
                    "evaluation": evaluation
                }
            else:
                return {
                    "test_id": test_case["id"],
                    "success": False,
                    "error": f"HTTP {response.status_code}",
                    "processing_time_ms": (time.time() - start_time) * 1000
                }
                
        except Exception as e:
            return {
                "test_id": test_case["id"],
                "success": False,
                "error": str(e),
                "processing_time_ms": (time.time() - start_time) * 1000
            }
    
    def _evaluate_result(self, result: Dict, expected: Dict) -> Dict:
        """Evaluate analysis result against expected values"""
        evaluation = {
            "category_match": result.get("category") == expected["category"],
            "score_in_range": expected["min_productivity_score"] <= result.get("productivity_score", 0) <= expected["max_productivity_score"],
            "keywords_found": 0,
            "confidence_reasonable": 0.3 <= result.get("confidence", 0) <= 1.0
        }
        
        # Check keyword overlap
        result_activities = set(result.get("key_activities", []))
        expected_keywords = set(expected.get("expected_keywords", []))
        if expected_keywords:
            evaluation["keywords_found"] = len(result_activities & expected_keywords) / len(expected_keywords)
        
        evaluation["overall_score"] = sum([
            evaluation["category_match"] * 0.4,
            evaluation["score_in_range"] * 0.3,
            evaluation["keywords_found"] * 0.2,
            evaluation["confidence_reasonable"] * 0.1
        ])
        
        return evaluation
    
    async def run_evaluation(self, test_cases: List[Dict], parallel: int = 5) -> Dict:
        """Run evaluation on test cases"""
        print(f"Starting evaluation of {len(test_cases)} test cases...")
        
        # Process in batches
        for i in range(0, len(test_cases), parallel):
            batch = test_cases[i:i+parallel]
            tasks = [self.evaluate_single(tc) for tc in batch]
            results = await asyncio.gather(*tasks)
            
            for result in results:
                self.test_results.append(result)
                self._update_metrics(result)
            
            print(f"Processed {min(i+parallel, len(test_cases))}/{len(test_cases)} tests")
        
        # Calculate final metrics
        self._calculate_final_metrics()
        
        return self.get_report()
    
    def _update_metrics(self, result: Dict):
        """Update running metrics"""
        self.metrics.total_tests += 1
        
        if result["success"]:
            self.metrics.successful_analyses += 1
            self.metrics.response_times.append(result["processing_time_ms"])
            
            # Update category scores
            category = result.get("result", {}).get("category", "Other")
            score = result.get("result", {}).get("productivity_score", 0)
            
            if category not in self.metrics.scores_by_category:
                self.metrics.scores_by_category[category] = []
            self.metrics.scores_by_category[category].append(score)
        else:
            self.metrics.failed_analyses += 1
            error_type = result.get("error", "Unknown")
            self.metrics.error_types[error_type] = self.metrics.error_types.get(error_type, 0) + 1
    
    def _calculate_final_metrics(self):
        """Calculate final aggregate metrics"""
        if self.metrics.response_times:
            self.metrics.average_processing_time_ms = statistics.mean(self.metrics.response_times)
        
        # Calculate category accuracy
        category_matches = sum(1 for r in self.test_results 
                              if r.get("success") and r.get("evaluation", {}).get("category_match"))
        if self.metrics.successful_analyses > 0:
            self.metrics.category_accuracy = category_matches / self.metrics.successful_analyses
        
        # Calculate average productivity score
        all_scores = []
        for scores in self.metrics.scores_by_category.values():
            all_scores.extend(scores)
        if all_scores:
            self.metrics.average_productivity_score = statistics.mean(all_scores)
        
        # Calculate confidence correlation
        confidences = []
        accuracies = []
        for r in self.test_results:
            if r.get("success"):
                confidence = r.get("result", {}).get("confidence", 0)
                accuracy = r.get("evaluation", {}).get("overall_score", 0)
                confidences.append(confidence)
                accuracies.append(accuracy)
        
        if len(confidences) > 1:
            # Simple correlation coefficient
            self.metrics.confidence_correlation = np.corrcoef(confidences, accuracies)[0, 1]
    
    def get_report(self) -> Dict:
        """Generate evaluation report"""
        return {
            "summary": {
                "total_tests": self.metrics.total_tests,
                "successful": self.metrics.successful_analyses,
                "failed": self.metrics.failed_analyses,
                "success_rate": self.metrics.successful_analyses / max(self.metrics.total_tests, 1)
            },
            "performance": {
                "average_response_time_ms": self.metrics.average_processing_time_ms,
                "p50_response_time_ms": statistics.median(self.metrics.response_times) if self.metrics.response_times else 0,
                "p95_response_time_ms": np.percentile(self.metrics.response_times, 95) if self.metrics.response_times else 0
            },
            "accuracy": {
                "category_accuracy": self.metrics.category_accuracy,
                "average_productivity_score": self.metrics.average_productivity_score,
                "confidence_correlation": self.metrics.confidence_correlation
            },
            "categories": {
                cat: {
                    "count": len(scores),
                    "avg_score": statistics.mean(scores) if scores else 0,
                    "std_dev": statistics.stdev(scores) if len(scores) > 1 else 0
                }
                for cat, scores in self.metrics.scores_by_category.items()
            },
            "errors": self.metrics.error_types,
            "detailed_results": self.test_results[:10]  # Include first 10 for inspection
        }
    
    def save_report(self, filepath: Path):
        """Save evaluation report to file"""
        report = self.get_report()
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        with open(filepath, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        print(f"Report saved to {filepath}")

async def main():
    """Run complete evaluation"""
    print("=" * 60)
    print("LLM Analysis Evaluation System")
    print("=" * 60)
    
    # Generate test data
    print("\n1. Generating synthetic test data...")
    generator = SyntheticDataGenerator()
    test_cases = generator.generate_test_suite(num_samples=100)
    
    # Save test cases for inspection
    test_file = Path("/tmp/llm_test_cases.json")
    with open(test_file, 'w') as f:
        json.dump(test_cases, f, indent=2)
    print(f"   Generated {len(test_cases)} test cases")
    print(f"   Saved to {test_file}")
    
    # Check server health
    print("\n2. Checking server health...")
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get("http://localhost:8765/health", timeout=5.0)
            if response.status_code == 200:
                health = response.json()
                print(f"   Server status: {health['status']}")
                print(f"   Ollama available: {health['ollama_available']}")
                print(f"   Model loaded: {health['model_loaded']}")
            else:
                print("   WARNING: Server health check failed")
        except Exception as e:
            print(f"   ERROR: Cannot connect to server: {e}")
            print("   Please ensure the server is running (python server.py)")
            return
    
    # Run evaluation
    print("\n3. Running evaluation...")
    evaluator = LLMAnalysisEvaluator()
    report = await evaluator.run_evaluation(test_cases, parallel=5)
    
    # Save report
    report_file = Path(f"/tmp/llm_evaluation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
    evaluator.save_report(report_file)
    
    # Print summary
    print("\n" + "=" * 60)
    print("EVALUATION RESULTS")
    print("=" * 60)
    print(f"\nSuccess Rate: {report['summary']['success_rate']:.2%}")
    print(f"Average Response Time: {report['performance']['average_response_time_ms']:.2f}ms")
    print(f"Category Accuracy: {report['accuracy']['category_accuracy']:.2%}")
    print(f"Average Productivity Score: {report['accuracy']['average_productivity_score']:.2f}/10")
    
    print("\nCategory Breakdown:")
    for cat, stats in report['categories'].items():
        print(f"  {cat:15} - Count: {stats['count']:3}, Avg Score: {stats['avg_score']:.2f}")
    
    if report['errors']:
        print("\nErrors Encountered:")
        for error, count in report['errors'].items():
            print(f"  {error}: {count}")
    
    print(f"\nDetailed report saved to: {report_file}")

if __name__ == "__main__":
    asyncio.run(main())