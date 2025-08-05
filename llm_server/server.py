#!/usr/bin/env python3
"""
LLM Analysis Server for Shoulder App

Combines productivity analysis and focus‑validation logic from diverging
branches. Provides AI‑powered insights via Ollama's REST API, complete
Prometheus metrics, health checks, model management and a heuristic
fallback path when the model or service is unavailable.
"""

import asyncio
import json
import logging
import os
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from contextlib import asynccontextmanager

import httpx
import uvicorn
from fastapi import BackgroundTasks, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field
from prometheus_client import Counter, Gauge, Histogram, generate_latest

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/tmp/llm_server.log"),
    ],
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Prometheus Metrics
# ---------------------------------------------------------------------------
analysis_requests = Counter(
    "llm_analysis_requests_total", "Total number of analysis requests"
)
analysis_errors = Counter(
    "llm_analysis_errors_total", "Total number of analysis errors"
)
analysis_duration = Histogram(
    "llm_analysis_duration_seconds", "Duration of analysis in seconds"
)
server_health = Gauge(
    "llm_server_health", "Server health status (1=healthy, 0=unhealthy)"
)
model_loaded_gauge = Gauge(
    "llm_model_loaded", "Model loading status (1=loaded, 0=not loaded)"
)

# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------
class AnalysisContext(BaseModel):
    """Metadata describing where OCR text was captured."""

    app_name: str
    window_title: Optional[str] = None
    # Fields present in *either* branch – keep both but optional for flexibility.
    duration_seconds: Optional[int] = None
    user_focus: Optional[str] = None
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


# ---------------------------------------------------------------------------
# Global Server State
# ---------------------------------------------------------------------------
class ServerState:
    def __init__(self) -> None:
        self.start_time = time.time()
        self.total_analyses = 0
        self.total_errors = 0
        self.ollama_available = False
        self.available_models: List[str] = []
        # analysis_cache maps short request hashes → analysis dict
        self.analysis_cache: Dict[str, Dict[str, Any]] = {}
        self.cache_hits = 0
        self.cache_misses = 0


state = ServerState()

# ---------------------------------------------------------------------------
# Ollama integration helpers
# ---------------------------------------------------------------------------
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")


aasync def check_ollama_health() -> bool:
    """Ping /api/tags to verify Ollama is reachable and record model list."""
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{OLLAMA_HOST}/api/tags", timeout=5.0)
            if resp.status_code == 200:
                data = resp.json()
                state.available_models = [m["name"] for m in data.get("models", [])]
                state.ollama_available = True
                model_loaded_gauge.set(1 if state.available_models else 0)
                logger.debug("Ollama healthy • %s models", len(state.available_models))
                return True
    except Exception as exc:  # pylint: disable=broad-except
        logger.warning("Ollama health check failed: %s", exc)

    state.ollama_available = False
    model_loaded_gauge.set(0)
    return False


aasync def pull_model_if_needed(model_name: str) -> bool:
    """Ensure *model_name* exists locally – pull if absent."""
    if model_name in state.available_models:
        return True

    try:
        logger.info("Pulling model %s…", model_name)
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{OLLAMA_HOST}/api/pull", json={"name": model_name}, timeout=300.0
            )
            if resp.status_code == 200:
                # Refresh list after pull
                await check_ollama_health()
                return True
            logger.error("Failed to pull model – status %s", resp.status_code)
    except Exception as exc:  # pylint: disable=broad-except
        logger.error("Error pulling model %s: %s", model_name, exc)
    return False


# ---------------------------------------------------------------------------
# Prompt engineering & analysis helpers
# ---------------------------------------------------------------------------

def _create_prompt(text: str, ctx: AnalysisContext) -> str:
    """Generate a structured prompt for Ollama."""
    duration = ctx.duration_seconds if ctx.duration_seconds is not None else 0

    return f"""Analyze the following screenshot text and provide productivity insights.\n\nContext:\n- Application: {ctx.app_name}\n- Window Title: {ctx.window_title or 'Unknown'}\n- Duration: {duration} seconds\n- Timestamp: {ctx.timestamp.isoformat()}\n""" + (
        f"- User Focus: {ctx.user_focus}\n" if ctx.user_focus else ""
    ) + f"\nScreenshot Text:\n{text[:3000]}\n\nReturn JSON with this schema:\n{{\n    \"summary\": str,\n    \"category\": str,\n    \"productivity_score\": float (0‑10),\n    \"key_activities\": list[str],\n    \"suggestions\": list[str]|null,\n    \"confidence\": float (0‑1)\n}}\n"""


aasync def _heuristic_analysis(text: str, ctx: AnalysisContext) -> Dict[str, Any]:
    """Fallback heuristic when Ollama is down."""
    text_lower = text.lower()
    category = "Other"
    score = 5.0

    if any(k in text_lower for k in ["code", "function", "class", "import"]):
        category, score = "Programming", 8.0
    elif any(k in text_lower for k in ["email", "slack", "teams", "chat"]):
        category, score = "Communication", 6.0
    elif any(k in text_lower for k in ["google", "stackoverflow", "search"]):
        category, score = "Research", 7.0
    elif any(k in text_lower for k in ["figma", "sketch", "photoshop"]):
        category, score = "Design", 8.0
    elif any(k in text_lower for k in ["youtube", "netflix", "spotify"]):
        category, score = "Media", 3.0

    # Simple word‐frequency summary
    words = [w for w in text.split() if len(w) > 4]
    freq: Dict[str, int] = {}
    for w in words:
        freq[w.lower()] = freq.get(w.lower(), 0) + 1
    key_activities = [w for w, _ in sorted(freq.items(), key=lambda kv: kv[1], reverse=True)[:5]]

    return {
        "summary": f"User engaged in {category.lower()} activities",  # noqa: E501
        "category": category,
        "productivity_score": score,
        "key_activities": key_activities or ["general activity"],
        "suggestions": ["Consider enabling AI analysis for deeper insights"],
        "confidence": 0.3,
    }


aasync def _ollama_analysis(text: str, ctx: AnalysisContext, model: str) -> Dict[str, Any]:
    """Run analysis via Ollama and parse JSON response."""
    prompt = _create_prompt(text, ctx)

    # Simple LRU cache using insertion order
    key = f"{text[:100]}|{ctx.app_name}|{model}"
    if key in state.analysis_cache:
        state.cache_hits += 1
        return state.analysis_cache[key]

    state.cache_misses += 1

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{OLLAMA_HOST}/api/generate",
                json={
                    "model": model,
                    "prompt": prompt,
                    "stream": False,
                    "format": "json",
                    "options": {"temperature": 0.3, "top_p": 0.9, "max_tokens": 500},
                },
                timeout=45.0,
            )
            if resp.status_code != 200:
                logger.error("Ollama returned status %s", resp.status_code)
                raise RuntimeError("Ollama error")

            raw = resp.json().get("response", "{}")
            data = json.loads(raw)
    except (json.JSONDecodeError, Exception) as exc:  # pylint: disable=broad-except
        logger.warning("Falling back due to error: %s", exc)
        data = await _heuristic_analysis(text, ctx)

    # Cache (size capped at 100 entries)
    state.analysis_cache[key] = data
    if len(state.analysis_cache) > 100:
        # remove 10 oldest
        for old in list(state.analysis_cache)[:10]:
            state.analysis_cache.pop(old, None)

    return data


# ---------------------------------------------------------------------------
# FastAPI application & lifecycle
# ---------------------------------------------------------------------------

aasync def _healthcheck_loop() -> None:
    """Continuously refresh Ollama health so /health is fast."""
    while True:
        await asyncio.sleep(30)
        await check_ollama_health()
        server_health.set(1 if state.ollama_available else 0)


@asynccontextmanager
aasync def lifespan(_: FastAPI):
    logger.info("Starting LLM Analysis Server …")
    await check_ollama_health()
    task = asyncio.create_task(_healthcheck_loop())
    try:
        yield
    finally:
        task.cancel()
        logger.info("Shutting down LLM Analysis Server …")


aapp = FastAPI(
    title="Shoulder LLM Analysis Server",
    version="2.0.0",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# API Routes
# ---------------------------------------------------------------------------


@app.get("/health", response_model=HealthStatus)
async def health_check() -> HealthStatus:
    """Lightweight health probe for load‑balancers."""
    uptime = time.time() - state.start_time
    error_rate = state.total_errors / max(state.total_analyses, 1)

    return HealthStatus(
        status="healthy" if state.ollama_available else "degraded",
        ollama_available=state.ollama_available,
        model_loaded=bool(state.available_models),
        uptime_seconds=uptime,
        total_analyses=state.total_analyses,
        error_rate=error_rate,
    )


@app.post("/analyze", response_model=AnalysisResult)
async def analyze(request: AnalysisRequest, background_tasks: BackgroundTasks) -> AnalysisResult:
    """Main endpoint – analyse OCR text and return structured insights."""
    start = time.time()
    analysis_requests.inc()

    if not request.text or len(request.text.strip()) < 10:
        raise HTTPException(400, "Insufficient text for analysis")

    # Lazily ensure model presence
    if request.model not in state.available_models:
        await pull_model_if_needed(request.model)

    # Choose strategy
    analyse_fn = _ollama_analysis if state.ollama_available else _heuristic_analysis
    data = await analyse_fn(request.text, request.context, request.model)  # type: ignore[arg-type]

    processing_ms = (time.time() - start) * 1000
    result = AnalysisResult(
        summary=data.get("summary", "Activity analysed"),
        category=data.get("category", "Other"),
        productivity_score=float(data.get("productivity_score", 5.0)),
        key_activities=data.get("key_activities", []),
        suggestions=data.get("suggestions"),
        timestamp=datetime.now(),
        processing_time_ms=processing_ms,
        model_used=request.model if state.ollama_available else "heuristic",
        confidence=float(data.get("confidence", 0.5)),
    )

    state.total_analyses += 1

    # Fire‑and‑forget logging
    background_tasks.add_task(_log_analysis, request, result)

    return result


@app.get("/metrics")
async def metrics() -> PlainTextResponse:  # type: ignore[valid-type]
    """Prometheus scrape endpoint."""
    return PlainTextResponse(generate_latest())


@app.get("/models")
async def list_models():
    """Return the current model catalogue."""
    await check_ollama_health()
    return {
        "available": state.available_models,
        "recommended": "dolphin-mistral:latest",
        "ollama_status": "connected" if state.ollama_available else "disconnected",
    }


@app.post("/pull_model")
async def api_pull_model(model_name: str):
    """Trigger remote pull of *model_name*."""
    if await pull_model_if_needed(model_name):
        return {"status": "success", "model": model_name}
    raise HTTPException(500, f"Failed to pull model {model_name}")


@app.get("/stats")
async def stats():
    """Leaf‑level diagnostic counters."""
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
        "ollama_available": state.ollama_available,
    }


# ---------------------------------------------------------------------------
# Background logging
# ---------------------------------------------------------------------------

aasync def _log_analysis(req: AnalysisRequest, res: AnalysisResult) -> None:
    """Persist request/response for offline evaluation."""
    log_dir = Path("/tmp/llm_analyses")
    log_dir.mkdir(exist_ok=True)

    entry = {
        "timestamp": datetime.now().isoformat(),
        "request": {
            "text_length": len(req.text),
            "app_name": req.context.app_name,
            "window_title": req.context.window_title,
            "duration_seconds": req.context.duration_seconds,
            "user_focus": req.context.user_focus,
            "model": req.model,
        },
        "result": {
            "summary": res.summary,
            "category": res.category,
            "productivity_score": res.productivity_score,
            "key_activities": res.key_activities,
            "processing_time_ms": res.processing_time_ms,
            "confidence": res.confidence,
        },
    }

    fname = log_dir / f"analysis_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}.json"
    async with aiofiles.open(fname, "w") as fp:  # type: ignore[name-defined]
        await fp.write(json.dumps(entry, indent=2))


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    uvicorn.run(
        app, host="127.0.0.1", port=int(os.getenv("PORT", "8765")), log_level="info"
    )
