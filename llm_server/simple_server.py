#!/usr/bin/env python3
"""
Simple LLM Analysis Server for Testing
"""

import json
import random
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

class SimpleHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        if self.path == '/health':
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
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/analyze':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                request = json.loads(post_data)
                text = request.get('text', '').lower()
                context = request.get('context', {})
                
                # Simulate processing
                time.sleep(random.uniform(0.05, 0.2))
                
                # Determine category
                if any(kw in text for kw in ['function', 'class', 'import', 'struct', 'def']):
                    category = "Programming"
                    score = random.uniform(7.5, 9.0)
                elif any(kw in text for kw in ['email', 'message', 'chat', 'meeting']):
                    category = "Communication"
                    score = random.uniform(5.0, 7.0)
                elif any(kw in text for kw in ['search', 'documentation', 'stackoverflow']):
                    category = "Research"
                    score = random.uniform(6.5, 8.5)
                elif any(kw in text for kw in ['document', 'report', 'notes']):
                    category = "Documentation"
                    score = random.uniform(7.0, 8.5)
                elif any(kw in text for kw in ['video', 'youtube', 'music']):
                    category = "Media"
                    score = random.uniform(2.0, 4.0)
                elif any(kw in text for kw in ['finder', 'terminal', 'settings']):
                    category = "System"
                    score = random.uniform(4.0, 6.0)
                else:
                    category = "Other"
                    score = random.uniform(3.0, 7.0)
                
                # Extract keywords
                words = text.split()
                keywords = [w for w in words if len(w) > 5][:5]
                if not keywords:
                    keywords = ["activity", "task"]
                
                response = {
                    "summary": f"User engaged in {category.lower()} activities",
                    "category": category,
                    "productivity_score": round(score, 1),
                    "key_activities": keywords,
                    "suggestions": None,
                    "timestamp": datetime.now().isoformat(),
                    "processing_time_ms": random.uniform(50, 200),
                    "model_used": "mock",
                    "confidence": random.uniform(0.7, 0.95)
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
    
    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {format % args}")

if __name__ == "__main__":
    server = HTTPServer(('127.0.0.1', 8765), SimpleHandler)
    print("Simple LLM Server running on port 8765")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")
        server.shutdown()