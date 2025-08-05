#!/usr/bin/env python3
"""
Mock LLM Analysis Server for testing
Provides simulated AI analysis responses
"""

import json
import random
import time
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

class MockLLMHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            response = {
                "status": "healthy",
                "ollama_available": True,
                "model_loaded": True,
                "uptime_seconds": 100.0,
                "total_analyses": 42,
                "error_rate": 0.02
            }
            self.wfile.write(json.dumps(response).encode())
        
        elif parsed_path.path == '/models':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            response = {
                "available": ["dolphin-mistral:latest", "mock-model:latest"],
                "recommended": "dolphin-mistral:latest",
                "ollama_status": "connected"
            }
            self.wfile.write(json.dumps(response).encode())
        
        elif parsed_path.path == '/stats':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            response = {
                "uptime_seconds": 100.0,
                "total_analyses": 42,
                "total_errors": 1,
                "error_rate": 0.024,
                "cache_hits": 15,
                "cache_misses": 27,
                "cache_hit_rate": 0.357,
                "models_loaded": 2,
                "ollama_available": True
            }
            self.wfile.write(json.dumps(response).encode())
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/analyze':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                request = json.loads(post_data)
                
                # Simulate processing delay
                time.sleep(random.uniform(0.1, 0.5))
                
                # Generate mock analysis based on text content
                text = request.get('text', '').lower()
                context = request.get('context', {})
                
                # Determine category based on keywords
                category = "Other"
                productivity_score = 5.0
                
                if any(kw in text for kw in ['function', 'class', 'import', 'def', 'var', 'struct']):
                    category = "Programming"
                    productivity_score = random.uniform(7.5, 9.0)
                elif any(kw in text for kw in ['email', 'message', 'chat', 'slack', 'meeting']):
                    category = "Communication"
                    productivity_score = random.uniform(5.0, 7.0)
                elif any(kw in text for kw in ['google', 'search', 'stackoverflow', 'documentation']):
                    category = "Research"
                    productivity_score = random.uniform(6.5, 8.0)
                elif any(kw in text for kw in ['document', 'report', 'presentation', 'notes']):
                    category = "Documentation"
                    productivity_score = random.uniform(6.5, 8.5)
                elif any(kw in text for kw in ['design', 'figma', 'sketch', 'layout']):
                    category = "Design"
                    productivity_score = random.uniform(7.0, 9.0)
                elif any(kw in text for kw in ['video', 'youtube', 'netflix', 'music']):
                    category = "Media"
                    productivity_score = random.uniform(2.0, 4.0)
                elif any(kw in text for kw in ['finder', 'system', 'terminal', 'activity']):
                    category = "System"
                    productivity_score = random.uniform(4.0, 6.0)
                
                # Generate key activities
                words = text.split()
                key_activities = []
                for word in words:
                    if len(word) > 5 and not word.startswith('http'):
                        key_activities.append(word)
                        if len(key_activities) >= 5:
                            break
                
                if not key_activities:
                    key_activities = ["general activity", "task completion"]
                
                # Generate response
                response = {
                    "summary": f"User engaged in {category.lower()} activities in {context.get('app_name', 'application')}",
                    "category": category,
                    "productivity_score": round(productivity_score, 1),
                    "key_activities": key_activities,
                    "suggestions": [
                        f"Consider focusing on {category.lower()} tasks",
                        "Take regular breaks to maintain productivity"
                    ] if productivity_score < 7 else None,
                    "timestamp": datetime.now().isoformat(),
                    "processing_time_ms": round((time.time() - time.time()) * 1000 + random.uniform(100, 500), 2),
                    "model_used": "mock-model",
                    "confidence": round(random.uniform(0.7, 0.95), 2)
                }
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = {"error": str(e)}
                self.wfile.write(json.dumps(error_response).encode())
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Custom log message format"""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {format % args}")

def run_server(port=8765):
    """Run the mock server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, MockLLMHandler)
    print(f"Mock LLM Server running on port {port}")
    print("Press Ctrl+C to stop")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")
        httpd.shutdown()

if __name__ == "__main__":
    run_server()