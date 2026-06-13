import logging
import os
import sys
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Add current directory to path so we can import core modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Singletons (eagerly loaded in lifespan) ─────────────────────────────────
_rag = None
_llm = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _rag, _llm
    try:
        logger.info("Loading RAG engine...")
        from core.rag import RAGEngine

        _rag = RAGEngine()
        _rag.load()
        logger.info("RAG engine loaded successfully")

        logger.info("Loading LLM client...")
        from core.llm import LLMClient

        _llm = LLMClient()
        logger.info("LLM client loaded successfully")

        logger.info("OmniMind API ready to accept requests")
        yield
    finally:
        logger.info("Shutting down OmniMind API")


def get_rag():
    return _rag


def get_llm():
    return _llm


# ── App ───────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="OmniMind API",
    description="AI-Powered Mental Health System — Sukkur IBA University FYDP",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── In-memory session store (replace with Firebase for production) ─────────────
# sessions[session_id] = { history, assessment_mgr, progress, exercises_done, turn_count }
sessions: Dict[str, dict] = {}


def _new_session_data() -> dict:
    from core.assessments import AssessmentManager

    return {
        "session_id": str(uuid.uuid4()),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "history": [],
        "assessment_mgr": AssessmentManager(),
        "progress": [],
        "exercises_done": [],
        "turn_count": 0,
    }


def _get_or_create(session_id: Optional[str]) -> Tuple[str, dict]:
    if session_id and session_id in sessions:
        return session_id, sessions[session_id]
    sid = session_id or str(uuid.uuid4())
    sessions[sid] = _new_session_data()
    # Ensure session_id key matches requested sid
    sessions[sid]["session_id"] = sid
    return sid, sessions[sid]


# ── Pydantic models ───────────────────────────────────────────────────────────


class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    post_exercise: bool = False


class ChatResponse(BaseModel):
    session_id: str
    reply: str
    emotion: str
    crisis_detected: bool
    crisis_risk: Dict[str, Any] = {}

    exercise_suggestion: Optional[dict] = None
    assessment_updates: List[dict] = []
    assessment_scores: Dict[str, dict] = {}

    latency_ms: float
    turn: int


class AssessmentAnswerRequest(BaseModel):
    session_id: str
    assessment_name: str
    question_id: str
    score: int


class NewSessionResponse(BaseModel):
    session_id: str
    created_at: str


class NewSessionRequest(BaseModel):
    session_id: Optional[str] = None


# ── Helper — pick an exercise to suggest ─────────────────────────────────────

def _maybe_suggest_exercise(
    emotion: str,
    turn_count: int,
    exercises_done: list,
) -> Optional[dict]:
    # Trigger at turns 4, 8, 12, 16...
    trigger_emotions = [
        "anxiety",
        "stress",
        "depression",
        "social_anxiety",
        "anger",
        "ptsd",
        "fear",
        "sadness",
        "overwhelmed",
    ]

    is_trigger_turn = (turn_count > 0 and turn_count % 4 == 0)
    is_strong_emotion = emotion in trigger_emotions

    # Early trigger at turn 3 for strong anxiety/stress/crisis-like emotion
    early_trigger = (turn_count == 3 and emotion in ["anxiety", "stress", "crisis"])

    if not (is_trigger_turn and is_strong_emotion) and not early_trigger:
        return None

    try:
        from core.exercises import EXERCISES
    except Exception as e:
        logger.exception("Exercise import error: %s", e)
        return None

    if not EXERCISES:
        return None

    emotion_map = {
        "anxiety": "breathing_478",
        "stress": "breathing_478",
        "fear": "breathing_478",
        "social_anxiety": "grounding_54321",
        "depression": "behavioral_activation",
        "anger": "pmr",
        "ptsd": "pmr",
        "sadness": "behavioral_activation",
        "overwhelmed": "grounding_54321",
        "crisis": "breathing_478",
    }

    preferred_id = emotion_map.get(emotion, "breathing_478")

    # Try preferred exercise first
    if preferred_id not in exercises_done:
        ex = EXERCISES.get(preferred_id)
        if ex is not None:
            return {
                "id": ex.id,
                "name": ex.name,
                "tagline": ex.tagline,
                "duration_min": ex.duration_min,
                "intro_message": ex.intro_message,
                "steps": ex.steps,
                "post_prompt": ex.post_prompt,
            }

    # Fallback to any exercise not done yet
    for ex_id, ex in EXERCISES.items():
        if ex_id not in exercises_done and ex is not None:
            return {
                "id": ex.id,
                "name": ex.name,
                "tagline": ex.tagline,
                "duration_min": ex.duration_min,
                "intro_message": ex.intro_message,
                "steps": ex.steps,
                "post_prompt": ex.post_prompt,
            }

    return None


# ── Assessment helper ─────────────────────────────────────────────────────────

def _risk_from_severity_label(sev_label: str) -> str:
    s = (sev_label or "").lower()
    if "severe" in s or "high" in s:
        return "high"
    if "moderate" in s:
        return "moderate"
    return "low"


def _build_assessment_updates(mgr) -> List[dict]:
    updates: List[dict] = []
    for a in mgr.all:
        sev_label, _color = a.severity()
        answers: Dict[str, int] = {}
        for idx, q in enumerate(a.questions):
            sc = q.active_score()
            if sc is not None:
                answers[f"q{idx}"] = int(sc)

        updates.append(
            {
                "assessment_name": a.name,
                "score": int(a.total_score()),
                "severity": sev_label,
                "interpretation": a.interpretation_text(),
                "answers": answers,
                "riskLevel": _risk_from_severity_label(sev_label),
                "completedAt": None,
            }
        )
    return updates


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "model": "llama-3.1-8b-instant", "service": "OmniMind API"}


@app.get("/warmup")
def warmup():
    ready = _rag is not None and _llm is not None
    return {"status": "ready" if ready else "loading", "ready": ready}


@app.post("/session/new", response_model=NewSessionResponse)
def new_session(req: NewSessionRequest = NewSessionRequest()):
    """
    Create a new backend session.

    If req.session_id is provided, we seed the backend in-memory session
    under that exact id so the Flutter client can use a consistent session_id.
    """
    if req.session_id:
        sid = str(req.session_id)
        if sid not in sessions:
            data = _new_session_data()
            data["session_id"] = sid
            sessions[sid] = data
        else:
            data = sessions[sid]
        logger.info("New/seed session (client-provided): %s", sid)
        return NewSessionResponse(session_id=sid, created_at=data["created_at"])

    data = _new_session_data()
    sid = data["session_id"]
    sessions[sid] = data
    logger.info("New session: %s", sid)
    return NewSessionResponse(session_id=sid, created_at=data["created_at"])


@app.post("/session/restore")
def restore_session(data: dict):
    session_id = data.get("session_id")
    messages = data.get("messages", [])

    if not session_id:
        raise HTTPException(status_code=400, detail="session_id required")

    sid, sess = _get_or_create(str(session_id))
    mgr = sess["assessment_mgr"]

    for msg in messages:
        if isinstance(msg, dict):
            content = msg.get("content", "")
            if content:
                mgr.update_from_text(content)
                sess["turn_count"] += 1

    return {
        "status": "restored",
        "session_id": sid,
        "turns_replayed": sess["turn_count"],
    }


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    sid, sess = _get_or_create(req.session_id)

    rag = get_rag()
    llm = get_llm()
    if rag is None or llm is None:
        raise HTTPException(status_code=503, detail="Backend not warmed up")

    mgr = sess["assessment_mgr"]

    rag_ctx, _ = rag.retrieve(req.message)

    # Update assessments from user text
    mgr.update_from_text(req.message)

    assessment_summary = mgr.summary_for_llm() if hasattr(mgr, "summary_for_llm") else ""

    from core.crisis_classifier import classify_crisis_risk, FIXED_CRISIS_SUPPORT_MESSAGE

    # Best-effort crisis classification: never block chat response
    try:
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
            future = ex.submit(
                classify_crisis_risk,
                user_text=req.message,
                rag_ctx=rag_ctx,
                llm_client=llm,
            )
            # Quick-win latency: don’t wait up to 12s for crisis classification.
            # If it doesn’t finish quickly, continue with safe defaults.
            risk = future.result(timeout=1.0)  # seconds
    except Exception as _e:
        logger.warning("Crisis classifier timed out/failed: %s", _e)
        from core.crisis_classifier import CrisisRisk
        risk = CrisisRisk(
            risk_level=0,
            category="none",
            confidence=0.0,
            rationale="Crisis classifier unavailable (timeout/failed).",
        )


    crisis_detected = risk.risk_level >= 2
    crisis_risk = risk.to_dict()

    latency = 0.0

    if risk.risk_level == 3:
        reply = FIXED_CRISIS_SUPPORT_MESSAGE
        emotion = "crisis"
        llm.tracker.crisis_events += 1
        latency = 0.0
        mgr.update_from_text(reply)
    else:
        result = llm.generate(
            user_message=req.message,
            history=sess["history"],
            rag_context=rag_ctx,
            assessment_summary=assessment_summary,
            post_exercise=req.post_exercise,
        )

        reply = result["reply"]
        emotion = result["emotion"]
        latency = result["latency_ms"]

        if risk.risk_level >= 2:
            safety_prefix = (
                "Before we continue, I want to check on your safety. "
                "If you feel at risk of harming yourself or others, "
                "please reach out to immediate, real-world help right now.\n"
            )
            safety_suffix = (
                "\n\nIf you’re in immediate danger, call emergency services "
                "(115 in Pakistan · 911 in USA · 999 in UK). "
                "If you’re in Pakistan, you can contact Umang (0317-4288665) "
                "or Rozan (051-2890505). If you’re elsewhere, use "
                "https://www.findahelpline.com"
            )
            reply = safety_prefix + reply + safety_suffix
            emotion = "crisis"
            llm.tracker.crisis_events += 1

        mgr.update_from_text(reply)

    assessment_updates = _build_assessment_updates(mgr)

    scores: Dict[str, dict] = {}
    for a in mgr.all:
        sev_label, _color = a.severity()
        scores[a.name] = {
            "score": int(a.total_score()),
            "severity": sev_label,
            "completion_pct": round(a.completion_pct(), 1),
        }

    # Update history
    sess["history"].append({"role": "user", "content": req.message})
    sess["history"].append({"role": "assistant", "content": reply})

    # Increment BEFORE exercise suggestion
    sess["turn_count"] += 1

    # Then check exercise with updated count
    exercise = _maybe_suggest_exercise(
        emotion,
        sess["turn_count"],
        sess["exercises_done"],
    )
    if exercise:
        llm.tracker.exercises_triggered += 1

    sess["progress"].append(
        {
            "turn": sess["turn_count"],
            "emotion": emotion,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )

    return ChatResponse(
        session_id=sid,
        reply=reply,
        emotion=emotion,
        crisis_detected=crisis_detected,
        crisis_risk=crisis_risk,
        exercise_suggestion=exercise,
        assessment_updates=assessment_updates,
        assessment_scores=scores,
        latency_ms=latency,
        turn=sess["turn_count"],
    )


@app.post("/exercise/complete")
def complete_exercise(data: dict):
    session_id = data.get("session_id", "")
    exercise_id = data.get("exercise_id", "")
    if session_id in sessions and exercise_id:
        sessions[session_id]["exercises_done"].append(exercise_id)
    return {"status": "recorded"}


@app.post("/assess/answer")
def submit_assessment_answer(req: AssessmentAnswerRequest):
    if req.session_id not in sessions:
        raise HTTPException(404, "Session not found")
    mgr = sessions[req.session_id]["assessment_mgr"]
    mgr.set_direct(req.assessment_name, req.question_id, req.score)
    return {
        "status": "recorded",
        "assessment": req.assessment_name,
        "question": req.question_id,
    }


@app.get("/assess/status")
def get_assessment_status(session_id: Optional[str] = None):
    result: List[dict] = []
    if session_id is not None and session_id in sessions:
        mgr = sessions[session_id]["assessment_mgr"]
        for a in mgr.all:
            sev, color = a.severity()
            result.append(
                {
                    "name": a.name,
                    "full_name": a.full_name,
                    "domain": a.domain,
                    "score": a.total_score(),
                    "answered": a.answered_count(),
                    "total_questions": len(a.questions),
                    "completion_pct": round(a.completion_pct(), 1),
                    "severity": sev,
                    "severity_color": color,
                    "interpretation": a.interpretation_text(),
                    "questions": [
                        {
                            "id": q.id,
                            "text": q.text,
                            "options": q.options,
                            "scores": q.scores,
                            "answered_score": q.active_score(),
                            "answered_label": q.option_label(),
                        }
                        for q in a.questions
                    ],
                }
            )

    from core.assessments import AssessmentManager

    mgr = AssessmentManager()
    return {
        "assessments": result,
        "overall_risk": mgr.overall_risk(),
        "risk_flags": mgr.get_risk_flags(),
        "combined_risk_score": mgr.get_combined_risk_score(),
    }


@app.get("/progress")
def get_progress(session_id: str):
    if session_id not in sessions:
        raise HTTPException(404, "Session not found")

    sess = sessions[session_id]
    emotion_counts: Dict[str, int] = {}
    for p in sess["progress"]:
        e = p["emotion"]
        emotion_counts[e] = emotion_counts.get(e, 0) + 1

    return {
        "session_id": session_id,
        "turn_count": sess["turn_count"],
        "exercises_done": sess["exercises_done"],
        "emotion_history": sess["progress"],
        "emotion_counts": emotion_counts,
        "created_at": sess.get("created_at", ""),
    }


@app.get("/exercises")
def list_exercises():
    from core.exercises import EXERCISES

    return {
        "exercises": [
            {
                "id": ex.id,
                "name": ex.name,
                "domains": ex.domains,
                "tagline": ex.tagline,
                "duration_min": ex.duration_min,
                "intro_message": ex.intro_message,
                "steps": ex.steps,
                "post_prompt": ex.post_prompt,
                "evidence": ex.evidence,
            }
            for ex in EXERCISES.values()
        ]
    }


@app.get("/exercise/{exercise_id}")
def get_exercise(exercise_id: str):
    from core.exercises import EXERCISES

    ex = EXERCISES.get(exercise_id)
    if not ex:
        raise HTTPException(404, f"Exercise '{exercise_id}' not found")

    return {
        "id": ex.id,
        "name": ex.name,
        "domains": ex.domains,
        "tagline": ex.tagline,
        "duration_min": ex.duration_min,
        "intro_message": ex.intro_message,
        "steps": ex.steps,
        "post_prompt": ex.post_prompt,
        "evidence": ex.evidence,
    }


@app.get("/session/export")
def export_session(session_id: str):
    if session_id not in sessions:
        raise HTTPException(404, "Session not found")

    sess = sessions[session_id]
    mgr = sess["assessment_mgr"]

    return {
        "session_id": session_id,
        "created_at": sess.get("created_at"),
        "turn_count": sess["turn_count"],
        "history": sess["history"],
        "exercises_done": sess["exercises_done"],
        "progress": sess["progress"],
        "assessments": [
            {
                "name": a.name,
                "score": a.total_score(),
                "severity": a.severity()[0],
                "completion_pct": round(a.completion_pct(), 1),
                "item_scores": [
                    q.active_score()
                    for q in a.questions
                    if q.active_score() is not None
                ],
            }
            for a in mgr.all
        ],
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
