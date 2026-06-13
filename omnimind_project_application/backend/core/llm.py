"""core/llm.py — LLaMA 3 8B Instruct via Groq with full performance tracking."""
import time
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Dict
from groq import Groq
from config import GROQ_API_KEY, GROQ_MODEL, MAX_TOKENS, TEMPERATURE, HISTORY_KEEP

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """\
You are Dr. Mira, a highly experienced clinical psychologist with 15 years of expertise in \
CBT, mindfulness-based therapy, and crisis intervention. You are conducting a confidential \
therapeutic session via a mobile/web application.

STRICT RULES — follow these exactly:
1. Respond with genuine warmth, empathy and curiosity — never clinical coldness.
2. Ask EXACTLY ONE follow-up question per response. Never ask two questions at once.
3. Use the patient's own words back to them (reflective listening technique).
4. Always validate emotions BEFORE offering any technique or reframe.
5. Never use clinical test names (PHQ-9, GAD-7, CBT, cognitive distortion, etc.).
6. Keep responses to 3-5 sentences unless the patient is sharing a great deal.
7. Build understanding gradually across turns — map their mental state naturally over time.
8. When offering a therapeutic exercise, present it as a warm invitation, not a prescription.
9. After a patient completes an exercise, acknowledge what they experienced then continue the clinical conversation.
10. Maintain the Dr. Mira persona completely throughout the entire session.
11. If the patient mentions physical symptoms (headaches, fatigue, body pain), explore these gently — in Pakistani/South Asian context, these often express emotional distress.
12. If the patient mentions faith, prayer, or religious practice — respect and acknowledge these as genuine sources of strength.

CLINICAL APPROACH (internal — never state to patient):
- Track depression, anxiety, stress, and social anxiety signals throughout conversation.
- Progress naturally: rapport → symptom exploration → gentle intervention.
- Adapt pace: slower with fragile patients, deeper with engaged ones.
- If risk appears moderate or high, assess safety before interventions.
"""

EMOTION_KEYWORDS = {
    "depression":     ["sad","hopeless","depressed","empty","worthless","numb","tearful",
                       "can't enjoy","no motivation","tired all the time","feel nothing"],
    "anxiety":        ["anxious","worried","nervous","panic","scared","dread","tense",
                       "heart racing","can't breathe","overthinking","fear","on edge"],
    "stress":         ["stressed","overwhelmed","too much","pressure","can't cope",
                       "falling apart","burned out","exhausted","deadline","work"],
    "social_anxiety": ["embarrassed","judged","scared of people","avoid","can't talk",
                       "humiliated","shy","social situations","people watching"],
    "anger":          ["angry","frustrated","furious","irritated","rage","annoyed"],
}


def detect_emotion(text: str) -> str:
    text_l = text.lower()
    scores = {e: sum(1 for kw in kws if kw in text_l) for e, kws in EMOTION_KEYWORDS.items()}
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "neutral"


@dataclass
class CallMetric:
    timestamp: str
    turn: int
    prompt_tokens: int
    completion_tokens: int
    latency_ms: float
    response_length: int
    rag_used: bool
    emotion: str
    model: str = GROQ_MODEL


@dataclass
class PerformanceTracker:
    metrics: List[CallMetric] = field(default_factory=list)
    crisis_events: int = 0
    exercises_triggered: int = 0

    def add(self, m: CallMetric):
        self.metrics.append(m)

    def summary(self) -> dict:
        if not self.metrics:
            return {}
        lats  = [m.latency_ms          for m in self.metrics]
        ptoks = [m.prompt_tokens        for m in self.metrics]
        ctoks = [m.completion_tokens    for m in self.metrics]
        return {
            "model":                   GROQ_MODEL,
            "total_calls":             len(self.metrics),
            "avg_latency_ms":          round(sum(lats)  / len(lats),  1),
            "min_latency_ms":          round(min(lats),  1),
            "max_latency_ms":          round(max(lats),  1),
            "avg_prompt_tokens":       round(sum(ptoks) / len(ptoks), 1),
            "avg_completion_tokens":   round(sum(ctoks) / len(ctoks), 1),
            "total_tokens_used":       sum(ptoks) + sum(ctoks),
            "crisis_events":           self.crisis_events,
            "exercises_triggered":     self.exercises_triggered,
        }

    def emotion_dist(self) -> Dict[str, int]:
        d: Dict[str, int] = {}
        for m in self.metrics:
            d[m.emotion] = d.get(m.emotion, 0) + 1
        return d

    def all_rows(self) -> List[dict]:
        return [
            {"turn": m.turn, "latency_ms": m.latency_ms,
             "prompt_tokens": m.prompt_tokens, "completion_tokens": m.completion_tokens,
             "response_length": m.response_length, "rag_used": m.rag_used,
             "emotion": m.emotion, "timestamp": m.timestamp}
            for m in self.metrics
        ]


class LLMClient:
    def __init__(self):
        # Debug: show which Groq key the backend process sees (no full key printed)
        # This helps diagnose 401 invalid_api_key issues.
        key_preview = (GROQ_API_KEY[:3] + "…" + GROQ_API_KEY[-3:]) if GROQ_API_KEY else "<empty>"
        logger.info(f"[GroqKeyDebug] GROQ_API_KEY len={len(GROQ_API_KEY)} preview={key_preview}")

        if not GROQ_API_KEY or GROQ_API_KEY == "your_groq_api_key_here":

            logger.error("GROQ_API_KEY not set or invalid")
            raise RuntimeError(
                "GROQ_API_KEY not set. Open .env and paste your key from console.groq.com"
            )
        logger.info(f"Initializing Groq client with model: {GROQ_MODEL}")
        try:
            self.client  = Groq(api_key=GROQ_API_KEY)
            logger.info("Groq client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Groq client: {e}", exc_info=True)
            raise
        self.tracker = PerformanceTracker()
        self._turn   = 0

    def generate(self, user_message: str, history: List[Dict],
                 rag_context: str = "", assessment_summary: str = "",
                 post_exercise: bool = False) -> dict:
        """Generate a response from the LLM. Always returns a dict with keys:
        reply, latency_ms, prompt_tokens, completion_tokens, emotion, rag_used."""
        t0 = time.perf_counter()  # Start timer early to capture total latency
        try:
            self._turn += 1
            emotion  = detect_emotion(user_message)
            rag_used = bool(rag_context.strip())

            system = SYSTEM_PROMPT
            if assessment_summary:
                system += f"\n\n{assessment_summary}\n"
            if rag_context:
                system += (
                    "\n\n[CLINICAL REFERENCE — use to inform responses; "
                    "never quote directly or mention to patient]\n" + rag_context
                )
            if post_exercise:
                system += (
                    "\n\n[SESSION NOTE: Patient just finished a therapeutic exercise. "
                    "Acknowledge what they experienced warmly, then continue the clinical conversation.]"
                )

            messages = [{"role": "system", "content": system}]
            for h in history[-(HISTORY_KEEP * 2):]:
                if h["role"] in ("user", "assistant"):
                    messages.append({"role": h["role"], "content": h["content"]})
            messages.append({"role": "user", "content": user_message})

            logger.info(f"Turn {self._turn}: calling {GROQ_MODEL} with {len(messages)} messages")
            resp = self.client.chat.completions.create(
                model=GROQ_MODEL, messages=messages,
                max_tokens=MAX_TOKENS, temperature=TEMPERATURE,
            )
            latency = round((time.perf_counter() - t0) * 1000, 1)
            reply = resp.choices[0].message.content.strip()
            usage = resp.usage
            logger.info(f"Turn {self._turn}: success latency={latency}ms tokens={usage.prompt_tokens}+{usage.completion_tokens}")
            self.tracker.add(CallMetric(
                timestamp=datetime.now(timezone.utc).isoformat(),
                turn=self._turn,
                prompt_tokens=usage.prompt_tokens,
                completion_tokens=usage.completion_tokens,
                latency_ms=latency,
                response_length=len(reply),
                rag_used=rag_used,
                emotion=emotion,
            ))
            return {"reply": reply, "latency_ms": latency,
                    "prompt_tokens": usage.prompt_tokens,
                    "completion_tokens": usage.completion_tokens,
                    "emotion": emotion, "rag_used": rag_used}
        except Exception as e:
            latency = round((time.perf_counter() - t0) * 1000) if 't0' in locals() else 0
            logger.error(f"Turn {self._turn if hasattr(self, '_turn') else '?'}: LLM error: {e}", exc_info=True)
            # Return a structured error response that the UI can handle
            return {"reply": "I'm experiencing a technical difficulty and can't respond right now. Please try again in a moment.",
                    "latency_ms": latency, "prompt_tokens": 0,
                    "completion_tokens": 0, "emotion": "neutral",
                    "rag_used": rag_used if 'rag_used' in locals() else False,
                    "error": str(e)}
