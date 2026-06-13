"""
core/crisis_classifier.py — DSM-5–grounded crisis risk classifier (JSON output)

Goal:
- Replace keyword-only boolean crisis detection with DSM-5 evidence + LLM classification.
- Provide structured risk output:
  {
    "risk_level": 0-3,
    "category": "suicide | self-harm | violence | distress | none",
    "confidence": 0-1,
    "rationale": "DSM-5 grounded explanation..."
  }

Implementation:
- Uses existing RAG engine to retrieve DSM-5 style clinical evidence.
- Performs a single additional Groq LLM call that must return STRICT JSON.
"""
import json
import logging
from dataclasses import dataclass
from typing import Any, Dict, Optional

from core.llm import LLMClient
from core.rag import RAGEngine
from config import GROQ_MODEL, MAX_TOKENS, TEMPERATURE

logger = logging.getLogger(__name__)


@dataclass
class CrisisRisk:
    risk_level: int
    category: str
    confidence: float
    rationale: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "risk_level": int(self.risk_level),
            "category": str(self.category),
            "confidence": float(self.confidence),
            "rationale": str(self.rationale),
        }


STRICT_JSON_CLS_PROMPT = """\
You are a clinical risk classifier that uses DSM-5–grounded evidence.

Task:
Given:
1) The patient's message (user_text)
2) Retrieved DSM-5 clinical reference passages (rag_ctx)

Return STRICT JSON ONLY (no markdown, no extra keys):
{
  "risk_level": 0-3,
  "category": "suicide | self-harm | violence | distress | none",
  "confidence": 0-1,
  "rationale": "DSM-5 grounded explanation tying the message to the retrieved evidence. Be concise."
}

Risk scale:
0 = no concern
1 = mild distress
2 = moderate risk (safety support appropriate, monitor closely)
3 = high/imminent risk (active danger or clear intent/plan)

Rules:
- If there is any suggestion of suicide/intent/plan -> risk_level 3 or 2 depending on imminence/clarity.
- If there is self-harm without clear intent -> classify as self-harm; risk_level 2 unless clear imminence.
- If there is threats/intent/plan to harm others -> violence; risk_level 2 or 3 depending on imminence.
- Otherwise, classify distress if the user is persistently distressed (e.g., hopelessness, inability to cope), risk_level 1-2.
- If nothing relevant -> category "none" and risk_level 0, confidence low.

Important:
- Use DSM-5 evidence from rag_ctx as justification.
- Never output anything except the JSON object.
"""


FIXED_CRISIS_SUPPORT_MESSAGE = """\
I’m really glad you told me. What you shared sounds like a serious moment, and I want you to have immediate, real-world support right now.
If you are in immediate danger or might act on these thoughts, please call emergency services (115 in Pakistan · 911 in USA · 999 in UK).
If you’re in Pakistan, you can contact Umang (0317-4288665) or Rozan (051-2890505). If you’re elsewhere, use https://www.findahelpline.com
I’m here with you, and we can take the next step together—right now.
"""


def _safe_parse_json(text: str) -> Optional[Dict[str, Any]]:
    try:
        return json.loads(text)
    except Exception:
        # Try to extract the first JSON object in case the model included stray text
        try:
            start = text.find("{")
            end = text.rfind("}")
            if start != -1 and end != -1 and end > start:
                return json.loads(text[start:end + 1])
        except Exception:
            return None
    return None


def classify_crisis_risk(
    user_text: str,
    rag_ctx: str,
    llm_client: Optional[LLMClient] = None,
) -> CrisisRisk:
    """
    Classify crisis risk using:
    - user_text
    - DSM-5 evidence from rag_ctx
    - additional Groq call that returns strict JSON.
    """
    if not user_text or not user_text.strip():
        return CrisisRisk(
            risk_level=0,
            category="none",
            confidence=0.0,
            rationale="No input provided for crisis classification.",
        )

    # Create a temporary LLMClient if not injected (to reuse Groq client + api key validation)
    llm = llm_client or LLMClient()

    messages = [
        {"role": "system", "content": STRICT_JSON_CLS_PROMPT},
        {
            "role": "user",
            "content": (
                f"USER TEXT:\n{user_text}\n\n"
                f"DSM-5 RAG CONTEXT:\n{rag_ctx}\n\n"
                f"Now output the STRICT JSON response."
            ),
        },
    ]

    try:
        resp = llm.client.chat.completions.create(
            model=GROQ_MODEL,
            messages=messages,
            max_tokens=MAX_TOKENS,
            temperature=TEMPERATURE,
        )
        content = resp.choices[0].message.content.strip()
        parsed = _safe_parse_json(content)
        if not isinstance(parsed, dict):
            raise ValueError(f"Parsed JSON is not a dict: {parsed}")

        risk_level = int(parsed.get("risk_level", 0))
        category = str(parsed.get("category", "none"))
        confidence = float(parsed.get("confidence", 0.0))
        rationale = str(parsed.get("rationale", ""))

        # Normalize category to allowed set
        allowed = {"suicide", "self-harm", "violence", "distress", "none"}
        if category not in allowed:
            category = "none" if risk_level == 0 else "distress"

        # Clamp risk/confidence
        risk_level = max(0, min(3, risk_level))
        confidence = max(0.0, min(1.0, confidence))

        return CrisisRisk(
            risk_level=risk_level,
            category=category,
            confidence=confidence,
            rationale=rationale or "No rationale provided by classifier.",
        )
    except Exception as e:
        logger.exception("DSM-5 crisis classifier failed; falling back to safe defaults: %s", e)
        return CrisisRisk(
            risk_level=0,
            category="none",
            confidence=0.0,
            rationale=f"Classifier error: {e}",
        )


def get_rag_ctx_for_classifier(user_text: str, rag: Optional[RAGEngine] = None) -> str:
    rag_engine = rag or RAGEngine()
    if not getattr(rag_engine, "ready", False):
        # In the API we already load rag; this is just defensive.
        rag_engine.load()
    rag_ctx, _ = rag_engine.retrieve(user_text)
    return rag_ctx
