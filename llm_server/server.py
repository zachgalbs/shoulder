#!/usr/bin/env python3
"""
LLM Analysis Server for Shoulder App
Provides AI-powered productivity analysis using Ollama
"""

import asyncio
import json
import logging
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx
import aiofiles
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from fastapi.responses import PlainTextResponse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/tmp/llm_server.log')
    ]
)
logger = logging.getLogger(__name__)

# Metrics
analysis_requests = Counter('llm_analysis_requests_total', 'Total number of analysis requests')
analysis_errors = Counter('llm_analysis_errors_total', 'Total number of analysis errors')
analysis_duration = Histogram('llm_analysis_duration_seconds', 'Duration of analysis in seconds')
server_health = Gauge('llm_server_health', 'Server health status (1=healthy, 0=unhealthy)')
model_loaded = Gauge('llm_model_loaded', 'Model loading status (1=loaded, 0=not loaded)')

# Models
class AnalysisContext(BaseModel):
    app_name: str
    window_title: Optional[str] = None
    duration_seconds: int
    timestamp: datetime

class AnalysisRequest(BaseModel):
    text: str
    context: AnalysisContext
    model: str = "dolphin-mistral:latest"

class AnalysisResult(BaseModel):
    summary: str
    category: str
    productivity_score: float = Field(ge=0.0, le=10.0)
    key_activities: List[str]
    suggestions: Optional[List[str]] = None
    timestamp: datetime
    processing_time_ms: float
    model_used: str
    confidence: float = Field(ge=0.0, le=1.0)

class HealthStatus(BaseModel):
    status: str
    ollama_available: bool
    model_loaded: bool
    uptime_seconds: float
    total_analyses: int
    error_rate: float

# Global state
class ServerState:
    def __init__(self):
        self.start_time = time.time()
        self.total_analyses = 0
        self.total_errors = 0
        self.ollama_available = False
        self.available_models = []
        self.model_cache = {}
        self.analysis_cache = {}
        self.cache_hits = 0
        self.cache_misses = 0

state = ServerState()

# Ollama client
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")

async def check_ollama_health():
    """Check if Ollama is running and accessible"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{OLLAMA_HOST}/api/tags", timeout=5.0)
            if response.status_code == 200:
                data = response.json()
                state.available_models = [model['name'] for model in data.get('models', [])]
                state.ollama_available = True
                model_loaded.set(1 if state.available_models else 0)
                logger.info(f"Ollama is healthy. Available models: {state.available_models}")
                return True
    except Exception as e:
        logger.error(f"Ollama health check failed: {e}")
        state.ollama_available = False
        model_loaded.set(0)
    return False

async def pull_model_if_needed(model_name: str):
    """Pull model from Ollama if not available"""
    if model_name in state.available_models:
        return True
    
    try:
        logger.info(f"Pulling model {model_name}...")
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_HOST}/api/pull",
                json={"name": model_name},
                timeout=300.0
            )
            if response.status_code == 200:
                logger.info(f"Successfully pulled model {model_name}")
                await check_ollama_health()
                return True
    except Exception as e:
        logger.error(f"Failed to pull model {model_name}: {e}")
    return False

def create_analysis_prompt(text: str, context: AnalysisContext) -> str:
    """Create a structured prompt for productivity analysis"""
    return f"""Analyze the following screenshot text from {context.app_name} and provide productivity insights.

Context:
- Application: {context.app_name}
- Window Title: {context.window_title or 'Unknown'}
- Duration: {context.duration_seconds} seconds
- Timestamp: {context.timestamp.isoformat()}

Screenshot Text:
{text[:3000]}  # Limit text to prevent token overflow

Please provide a JSON response with the following structure:
{{
    "summary": "Brief 1-2 sentence summary of what the user was doing",
    "category": "One of: Programming, Communication, Research, Documentation, Design, Media, System, Other",
    "productivity_score": 7.5,  // Score from 0-10 based on productive activity
    "key_activities": ["list", "of", "main", "activities", "observed"],
    "suggestions": ["optional", "productivity", "improvement", "suggestions"],
    "confidence": 0.85  // Confidence in the analysis from 0-1
}}

Focus on:
1. Identifying the primary activity
2. Assessing productivity level
3. Extracting key actions or topics
4. Providing actionable insights when relevant
"""

async def analyze_with_ollama(text: str, context: AnalysisContext, model: str) -> Dict[str, Any]:
    """Send analysis request to Ollama"""
    prompt = create_analysis_prompt(text, context)
    
    # Check cache
    cache_key = f"{text[:100]}_{context.app_name}_{model}"
    if cache_key in state.analysis_cache:
        state.cache_hits += 1
        logger.info(f"Cache hit for analysis (hits: {state.cache_hits})")
        return state.analysis_cache[cache_key]
    
    state.cache_misses += 1
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_HOST}/api/generate",
                json={
                    "model": model,
                    "prompt": prompt,
                    "stream": False,
                    "format": "json",
                    "options": {
                        "temperature": 0.3,
                        "top_p": 0.9,
                        "max_tokens": 500
                    }
                },
                timeout=30.0
            )
            
            if response.status_code == 200:
                result = response.json()
                analysis_text = result.get('response', '{}')
                
                try:
                    analysis = json.loads(analysis_text)
                    # Cache the result
                    state.analysis_cache[cache_key] = analysis
                    # Limit cache size
                    if len(state.analysis_cache) > 100:
                        # Remove oldest entries
                        keys = list(state.analysis_cache.keys())[:10]
                        for k in keys:
                            del state.analysis_cache[k]
                    return analysis
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse Ollama response as JSON: {e}")
                    logger.error(f"Response was: {analysis_text}")
                    # Return a fallback analysis
                    return create_fallback_analysis(text, context)
            else:
                logger.error(f"Ollama returned status {response.status_code}")
                return create_fallback_analysis(text, context)
                
    except httpx.TimeoutException:
        logger.error("Ollama request timed out")
        return create_fallback_analysis(text, context)
    except Exception as e:
        logger.error(f"Ollama analysis failed: {e}")
        return create_fallback_analysis(text, context)

def create_fallback_analysis(text: str, context: AnalysisContext) -> Dict[str, Any]:
    """Create a fallback analysis when Ollama is unavailable"""
    # Simple heuristic-based analysis
    text_lower = text.lower()
    
    # Detect category based on keywords
    category = "Other"
    productivity_score = 5.0
    
    if any(kw in text_lower for kw in ['code', 'function', 'class', 'import', 'def', 'var', 'const']):
        category = "Programming"
        productivity_score = 8.0
    elif any(kw in text_lower for kw in ['email', 'message', 'chat', 'slack', 'teams']):
        category = "Communication"
        productivity_score = 6.0
    elif any(kw in text_lower for kw in ['google', 'search', 'stackoverflow', 'documentation']):
        category = "Research"
        productivity_score = 7.0
    elif any(kw in text_lower for kw in ['document', 'report', 'presentation', 'slides']):
        category = "Documentation"
        productivity_score = 7.5
    elif any(kw in text_lower for kw in ['design', 'figma', 'sketch', 'photoshop']):
        category = "Design"
        productivity_score = 8.0
    elif any(kw in text_lower for kw in ['video', 'youtube', 'netflix', 'spotify']):
        category = "Media"
        productivity_score = 3.0
    
    # Extract key activities (simple word frequency)
    words = text.split()
    word_freq = {}
    for word in words:
        if len(word) > 4:  # Filter short words
            word_freq[word.lower()] = word_freq.get(word.lower(), 0) + 1
    
    key_activities = [word for word, _ in sorted(word_freq.items(), key=lambda x: x[1], reverse=True)[:5]]
    
    return {
        "summary": f"User was engaged in {category.lower()} activities in {context.app_name}",
        "category": category,
        "productivity_score": productivity_score,
        "key_activities": key_activities or ["general activity"],
        "suggestions": ["Consider using AI analysis for better insights"],
        "confidence": 0.3
    }

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle"""
    # Startup
    logger.info("Starting LLM Analysis Server...")
    await check_ollama_health()
    
    # Start background health check
    async def periodic_health_check():
        while True:
            await asyncio.sleep(30)
            await check_ollama_health()
            server_health.set(1 if state.ollama_available else 0)
    
    task = asyncio.create_task(periodic_health_check())
    
    yield
    
    # Shutdown
    task.cancel()
    logger.info("Shutting down LLM Analysis Server...")

# Create FastAPI app
app = FastAPI(
    title="Shoulder LLM Analysis Server",
    description="AI-powered productivity analysis for screenshot OCR text",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", response_model=HealthStatus)
async def health_check():
    """Health check endpoint"""
    uptime = time.time() - state.start_time
    error_rate = state.total_errors / max(state.total_analyses, 1)
    
    status = HealthStatus(
        status="healthy" if state.ollama_available else "degraded",
        ollama_available=state.ollama_available,
        model_loaded=len(state.available_models) > 0,
        uptime_seconds=uptime,
        total_analyses=state.total_analyses,
        error_rate=error_rate
    )
    
    server_health.set(1 if state.ollama_available else 0)
    
    return status

@app.post("/analyze", response_model=AnalysisResult)
async def analyze_screenshot(request: AnalysisRequest, background_tasks: BackgroundTasks):
    """Analyze screenshot OCR text for productivity insights"""
    start_time = time.time()
    analysis_requests.inc()
    
    try:
        # Validate input
        if not request.text or len(request.text.strip()) < 10:
            raise HTTPException(status_code=400, detail="Insufficient text for analysis")
        
        # Check if Ollama is available
        if not state.ollama_available:
            await check_ollama_health()
        
        # Ensure model is available
        if request.model not in state.available_models:
            if not await pull_model_if_needed(request.model):
                # Use fallback model or heuristic analysis
                logger.warning(f"Model {request.model} not available, using fallback")
        
        # Perform analysis
        with analysis_duration.time():
            if state.ollama_available and request.model in state.available_models:
                analysis = await analyze_with_ollama(request.text, request.context, request.model)
            else:
                analysis = create_fallback_analysis(request.text, request.context)
        
        # Create result
        processing_time = (time.time() - start_time) * 1000
        
        result = AnalysisResult(
            summary=analysis.get("summary", "Activity analysis completed"),
            category=analysis.get("category", "Other"),
            productivity_score=min(10.0, max(0.0, float(analysis.get("productivity_score", 5.0)))),
            key_activities=analysis.get("key_activities", []),
            suggestions=analysis.get("suggestions"),
            timestamp=datetime.now(),
            processing_time_ms=processing_time,
            model_used=request.model if state.ollama_available else "heuristic",
            confidence=float(analysis.get("confidence", 0.5))
        )
        
        state.total_analyses += 1
        
        # Log analysis for evaluation
        background_tasks.add_task(log_analysis, request, result)
        
        logger.info(f"Analysis completed in {processing_time:.2f}ms")
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        state.total_errors += 1
        analysis_errors.inc()
        logger.error(f"Analysis failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@app.get("/metrics")
async def get_metrics():
    """Prometheus metrics endpoint"""
    return PlainTextResponse(generate_latest())

@app.get("/models")
async def list_models():
    """List available models"""
    await check_ollama_health()
    return {
        "available": state.available_models,
        "recommended": "dolphin-mistral:latest",
        "ollama_status": "connected" if state.ollama_available else "disconnected"
    }

@app.get("/stats")
async def get_statistics():
    """Get server statistics"""
    uptime = time.time() - state.start_time
    return {
        "uptime_seconds": uptime,
        "total_analyses": state.total_analyses,
        "total_errors": state.total_errors,
        "error_rate": state.total_errors / max(state.total_analyses, 1),
        "cache_hits": state.cache_hits,
        "cache_misses": state.cache_misses,
        "cache_hit_rate": state.cache_hits / max(state.cache_hits + state.cache_misses, 1),
        "models_loaded": len(state.available_models),
        "ollama_available": state.ollama_available
    }

async def log_analysis(request: AnalysisRequest, result: AnalysisResult):
    """Log analysis for evaluation purposes"""
    log_dir = Path("/tmp/llm_analyses")
    log_dir.mkdir(exist_ok=True)
    
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "request": {
            "text_length": len(request.text),
            "app_name": request.context.app_name,
            "window_title": request.context.window_title,
            "duration_seconds": request.context.duration_seconds,
            "model": request.model
        },
        "result": {
            "summary": result.summary,
            "category": result.category,
            "productivity_score": result.productivity_score,
            "key_activities": result.key_activities,
            "processing_time_ms": result.processing_time_ms,
            "confidence": result.confidence
        }
    }
    
    log_file = log_dir / f"analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    async with aiofiles.open(log_file, 'w') as f:
        await f.write(json.dumps(log_entry, indent=2))

if __name__ == "__main__":
    # Run the server
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8765,
        log_level="info",
        access_log=True
    )