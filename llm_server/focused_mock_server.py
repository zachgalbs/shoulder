#!/usr/bin/env python3
"""
Mock Server for Focus Classification Testing
Simulates LLM responses for focused/not_focused classification
"""

import json
import random
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime
from typing import Tuple

class FocusedMockHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = {
                "status": "healthy",
                "server": "focused_mock",
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/analyze_focus':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                request = json.loads(post_data)
                text = request.get('text', '').lower()
                context = request.get('context', {})
                user_focus = context.get('user_focus', '').lower()
                app_name = context.get('app_name', '').lower()
                
                # Simulate processing
                time.sleep(random.uniform(0.05, 0.15))
                
                # Determine if focused based on user goal and screen content
                classification, confidence = self.classify_focus(user_focus, app_name, text)
                
                # Add some noise to confidence for realism
                confidence = max(0.1, min(0.95, confidence + random.uniform(-0.1, 0.1)))
                
                response = {
                    "classification": classification,
                    "confidence": round(confidence, 3),
                    "reasoning": self.get_reasoning(user_focus, app_name, classification),
                    "timestamp": datetime.now().isoformat(),
                    "processing_time_ms": random.uniform(50, 150)
                }
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def classify_focus(self, user_focus: str, app_name: str, text: str) -> Tuple[str, float]:
        """Classify if user is focused based on their goal and current activity"""
        
        # Define focused app mappings
        focus_app_mappings = {
            "studying computer science": ["code", "xcode", "terminal", "stack overflow", "documentation"],
            "writing code": ["code", "xcode", "intellij", "sublime", "atom", "terminal"],
            "writing email": ["mail", "gmail", "outlook", "thunderbird"],
            "learning react": ["react", "documentation", "tutorial", "mdn", "javascript"],
            "designing": ["figma", "sketch", "photoshop", "illustrator", "design"],
            "analyzing": ["excel", "sheets", "tableau", "analytics", "dashboard"],
            "reading documentation": ["docs", "documentation", "api", "reference", "guide"],
            "debugging": ["debug", "console", "terminal", "error", "stack trace"],
            "meeting": ["zoom", "teams", "meet", "skype", "webex"],
            "presentation": ["powerpoint", "keynote", "slides", "deck"]
        }
        
        # Distraction indicators
        distractions = ["youtube", "netflix", "twitter", "facebook", "instagram", "reddit", 
                       "tiktok", "twitch", "spotify", "game", "whatsapp", "messenger"]
        
        # Check for obvious distractions
        for distraction in distractions:
            if distraction in app_name or distraction in text:
                # High confidence that they're not focused
                return ("not_focused", 0.85)
        
        # Check if activity matches focus
        for focus_keyword, related_apps in focus_app_mappings.items():
            if focus_keyword in user_focus:
                for app in related_apps:
                    if app in app_name or app in text:
                        # High confidence they're focused
                        return ("focused", 0.88)
        
        # Check for work-related content in general
        work_keywords = ["project", "task", "meeting", "deadline", "client", "code", 
                        "function", "class", "email", "report", "analysis", "design"]
        
        work_count = sum(1 for kw in work_keywords if kw in text)
        
        if work_count >= 3:
            # Moderate confidence they're focused
            return ("focused", 0.72)
        elif work_count >= 1:
            # Low confidence - could go either way
            return ("focused", 0.55)
        else:
            # Probably not focused but not certain
            return ("not_focused", 0.65)
    
    def get_reasoning(self, user_focus: str, app_name: str, classification: str) -> str:
        """Generate reasoning for the classification"""
        if classification == "focused":
            return f"The user's goal of '{user_focus}' aligns with their current activity in {app_name}"
        else:
            return f"The user's activity in {app_name} doesn't align with their stated goal of '{user_focus}'"
    
    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {format % args}")

def run_server(port=8765):
    """Run the focused mock server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, FocusedMockHandler)
    print(f"Focused Mock Server running on port {port}")
    print("Endpoints:")
    print("  GET  /health - Server health check")
    print("  POST /analyze_focus - Focus classification")
    print("\nPress Ctrl+C to stop")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")
        httpd.shutdown()

if __name__ == "__main__":
    run_server()