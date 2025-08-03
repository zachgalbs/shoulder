#!/usr/bin/env python3
"""
LLM Analysis Server for Shoulder App
Provides local AI analysis of screenshots and activity data
"""

import json
import asyncio
import logging
from datetime import datetime
from typing import Dict, List, Optional
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import ollama
from ollama import AsyncClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AnalysisContext(BaseModel):
    app_name: str
    window_title: Optional[str] = None
    user_focus: str
    timestamp: datetime

class AnalysisRequest(BaseModel):
    text: str
    context: AnalysisContext
    model: str = "llama3.2:3b"

class AnalysisResult(BaseModel):
    is_valid: bool  # True if activity matches focus
    explanation: str  # Why it's valid/invalid
    detected_activity: str  # What the user is actually doing
    confidence: float = Field(ge=0.0, le=1.0)  # Model confidence
    timestamp: str  # Use ISO8601 string for compatibility

class LLMAnalyzer:
    def __init__(self):
        self.client = AsyncClient()
        # Use available model, prefer llama3.2:3b if available
        self.model = self.get_available_model()
        self.ensure_model_available()
    
    def get_available_model(self):
        """Get the best available model"""
        try:
            response = ollama.list()
            # Handle both dict and object responses
            if hasattr(response, 'models'):
                models_list = response.models
            else:
                models_list = response.get('models', [])
            
            model_names = []
            for m in models_list:
                if hasattr(m, 'name'):
                    model_names.append(m.name)
                elif isinstance(m, dict):
                    model_names.append(m.get('name', ''))
            
            # Preferred models in order
            preferred = ["llama3.2:3b", "llama3.2:latest", "dolphin-mistral:latest", "llama3:latest"]
            
            for model in preferred:
                if any(model in name for name in model_names):
                    logger.info(f"Using model: {model}")
                    return model
            
            # If no preferred model, use first available
            if model_names:
                model = model_names[0].split(':')[0] + ':latest'
                logger.info(f"Using available model: {model}")
                return model
            
            # Default to dolphin-mistral since we know it's available
            return "dolphin-mistral:latest"
        except Exception as e:
            logger.error(f"Error checking models: {e}")
            return "dolphin-mistral:latest"
    
    def ensure_model_available(self):
        """Check if model is available, pull if necessary"""
        try:
            response = ollama.list()
            # Handle both dict and object responses
            if hasattr(response, 'models'):
                models_list = response.models
            else:
                models_list = response.get('models', [])
            
            model_names = []
            for m in models_list:
                if hasattr(m, 'name'):
                    model_names.append(m.name)
                elif isinstance(m, dict):
                    model_names.append(m.get('name', ''))
            
            if not any(self.model in name for name in model_names):
                logger.info(f"Pulling model {self.model}...")
                ollama.pull(self.model)
                logger.info(f"Model {self.model} ready")
            else:
                logger.info(f"Model {self.model} is available")
        except Exception as e:
            logger.error(f"Failed to ensure model availability: {e}")
    
    async def analyze(self, request: AnalysisRequest) -> AnalysisResult:
        """Analyze screenshot text and activity context"""
        
        logger.info("=" * 50)
        logger.info("🤖 LLM ANALYSIS PIPELINE - PYTHON SERVER")
        logger.info(f"Step 1: Received request from Swift app")
        logger.info(f"   App: {request.context.app_name}")
        logger.info(f"   Text length: {len(request.text)} chars")
        logger.info(f"   Model: {request.model}")
        
        prompt = self._build_prompt(request.text, request.context)
        logger.info(f"Step 2: Built prompt ({len(prompt)} chars)")
        logger.info(f"   Prompt preview: {prompt[:200]}...")
        
        try:
            logger.info(f"Step 3: Sending to Ollama ({request.model})...")
            start_time = datetime.now()
            
            response = await self.client.generate(
                model=request.model,
                prompt=prompt,
                options={
                    "temperature": 0.3,
                    "top_p": 0.9,
                    "max_tokens": 500
                }
            )
            
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info(f"Step 4: Ollama responded in {elapsed:.2f}s")
            logger.info(f"   Response length: {len(response.get('response', ''))} chars")
            
            result = self._parse_response(response['response'], request.context)
            
            logger.info(f"Step 5: Parsed response successfully")
            logger.info(f"   Focus: {request.context.user_focus}")
            logger.info(f"   Valid: {'✅ YES' if result.is_valid else '❌ NO'}")
            logger.info(f"   Activity: {result.detected_activity}")
            logger.info(f"   Explanation: {result.explanation}")
            logger.info(f"   Confidence: {result.confidence * 100:.0f}%")
            logger.info("=" * 50)
            
            return result
            
        except Exception as e:
            logger.error(f"❌ Analysis failed: {e}")
            logger.info("Step 5: Using fallback analysis")
            return self._fallback_analysis(request.text, request.context)
    
    def _build_prompt(self, text: str, context: AnalysisContext) -> str:
        """Build focus validation prompt"""
        
        return f"""You are a focus validator. Determine if the user's current activity matches their stated focus.

USER'S STATED FOCUS: {context.user_focus}

CURRENT ACTIVITY:
- Application: {context.app_name}
- Window: {context.window_title or "Unknown"}
- Screenshot text: {text[:1500]}

TASK: Does the current activity align with the user's focus of "{context.user_focus}"?

Respond with JSON only:
{{
  "is_valid": true/false,
  "detected_activity": "Brief description of what user is actually doing",
  "explanation": "Brief explanation of why this is/isn't aligned with their focus",
  "confidence": 0.0 to 1.0
}}

Examples:
- Focus: "Writing code", Activity: Using Xcode → valid: true
- Focus: "Writing code", Activity: Browsing Reddit → valid: false
- Focus: "Research", Activity: Reading documentation → valid: true

JSON response:"""
    
    def _parse_response(self, response: str, context: AnalysisContext) -> AnalysisResult:
        """Parse LLM response into structured result"""
        try:
            response = response.strip()
            if "```json" in response:
                response = response.split("```json")[1].split("```")[0]
            elif "```" in response:
                response = response.split("```")[1].split("```")[0]
            
            data = json.loads(response)
            
            return AnalysisResult(
                is_valid=bool(data.get("is_valid", False)),
                detected_activity=data.get("detected_activity", "Unknown activity"),
                explanation=data.get("explanation", "Unable to determine"),
                confidence=min(1.0, max(0.0, float(data.get("confidence", 0.5)))),
                timestamp=datetime.now().isoformat()
            )
        except Exception as e:
            logger.error(f"Failed to parse response: {e}")
            logger.error(f"Raw response was: {response[:500]}")
            return self._fallback_analysis("", context)
    
    def _fallback_analysis(self, text: str, context: AnalysisContext) -> AnalysisResult:
        """Fallback analysis when LLM fails"""
        # Simple heuristic: development apps are usually valid for "writing code"
        dev_apps = ["xcode", "vscode", "terminal", "sublime", "atom", "intellij"]
        is_dev_app = any(app in context.app_name.lower() for app in dev_apps)
        
        is_valid = False
        if "code" in context.user_focus.lower() and is_dev_app:
            is_valid = True
        elif "research" in context.user_focus.lower() and "safari" in context.app_name.lower():
            is_valid = True
        
        return AnalysisResult(
            is_valid=is_valid,
            detected_activity=f"Using {context.app_name}",
            explanation="Analysis unavailable - using simple heuristic",
            confidence=0.3,
            timestamp=datetime.now().isoformat()
        )
    
    def _guess_category(self, app_name: str) -> str:
        """Guess category based on app name"""
        app_lower = app_name.lower()
        
        categories = {
            "Development": ["code", "xcode", "terminal", "sublime", "atom", "intellij", "android studio"],
            "Communication": ["slack", "discord", "teams", "zoom", "mail", "messages"],
            "Research": ["safari", "chrome", "firefox", "edge", "arc"],
            "Documentation": ["notes", "notion", "obsidian", "pages", "word"],
            "Entertainment": ["spotify", "music", "tv", "youtube", "netflix"]
        }
        
        for category, keywords in categories.items():
            if any(keyword in app_lower for keyword in keywords):
                return category
        
        return "Other"

analyzer = LLMAnalyzer()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting LLM Analysis Server...")
    yield
    logger.info("Shutting down LLM Analysis Server...")

app = FastAPI(
    title="Shoulder LLM Analysis Server",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "model": analyzer.model,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/analyze", response_model=AnalysisResult)
async def analyze_activity(request: AnalysisRequest, background_tasks: BackgroundTasks):
    """Analyze activity screenshot and context"""
    try:
        result = await analyzer.analyze(request)
        return result
    except Exception as e:
        logger.error(f"Analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/models")
async def list_models():
    """List available models"""
    try:
        response = ollama.list()
        # Handle both dict and object responses
        if hasattr(response, 'models'):
            models_list = response.models
        else:
            models_list = response.get('models', [])
        
        model_names = []
        for m in models_list:
            if hasattr(m, 'name'):
                model_names.append(m.name)
            elif isinstance(m, dict):
                model_names.append(m.get('name', ''))
        
        return {"models": model_names}
    except Exception as e:
        return {"models": [], "error": str(e)}

@app.post("/pull_model")
async def pull_model(model_name: str):
    """Pull a new model"""
    try:
        ollama.pull(model_name)
        return {"status": "success", "model": model_name}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8765,
        log_level="info"
    )