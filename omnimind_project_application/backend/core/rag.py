"""core/rag.py — FAISS RAG engine."""
import pickle
from typing import List, Tuple
import faiss
import numpy as np
from sentence_transformers import SentenceTransformer
from config import DATA_DIR, INDEX_PATH, CHUNKS_PATH, EMBED_MODEL, CHUNK_SIZE, CHUNK_OVERLAP, TOP_K


def _chunk(text: str) -> List[str]:
    chunks, start = [], 0
    while start < len(text):
        end = min(start + CHUNK_SIZE, len(text))
        c   = text[start:end].strip()
        if len(c) > 80:
            chunks.append(c)
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return chunks


class RAGEngine:
    def __init__(self):
        self.embedder = SentenceTransformer(EMBED_MODEL)
        self.index: faiss.IndexFlatL2 = None
        self.chunks: List[str] = []
        self.ready = False

    def load(self, force_rebuild: bool = False):
        if not force_rebuild and INDEX_PATH.exists() and CHUNKS_PATH.exists():
            self.index = faiss.read_index(str(INDEX_PATH))
            with open(CHUNKS_PATH, "rb") as f:
                self.chunks = pickle.load(f)
            self.ready = True
            return

        docs = []
        for p in DATA_DIR.iterdir():
            try:
                if p.suffix.lower() == ".pdf":
                    import fitz
                    doc = fitz.open(str(p))
                    docs.append("\n".join(pg.get_text() for pg in doc))
                elif p.suffix.lower() in {".txt", ".md"}:
                    docs.append(p.read_text(encoding="utf-8", errors="ignore"))
            except Exception:
                pass

        if not docs:
            docs = [CORPUS]

        self.chunks = []
        for d in docs:
            self.chunks.extend(_chunk(d))

        embs = self.embedder.encode(self.chunks, show_progress_bar=False, batch_size=32).astype(np.float32)
        self.index = faiss.IndexFlatL2(embs.shape[1])
        self.index.add(embs)

        INDEX_PATH.parent.mkdir(exist_ok=True)
        faiss.write_index(self.index, str(INDEX_PATH))
        with open(CHUNKS_PATH, "wb") as f:
            pickle.dump(self.chunks, f)
        self.ready = True

    def retrieve(self, query: str) -> Tuple[str, bool]:
        if not self.ready or self.index is None or self.index.ntotal == 0:
            return "", False
        q_emb = self.embedder.encode([query]).astype(np.float32)
        _, idxs = self.index.search(q_emb, min(TOP_K, self.index.ntotal))
        passages = [self.chunks[i] for i in idxs[0] if 0 <= i < len(self.chunks)]
        return "\n\n---\n\n".join(passages), True


CORPUS = """
MAJOR DEPRESSIVE DISORDER (MDD) — DSM-5
Requires 5+ symptoms for at least 2 weeks; must include depressed mood or anhedonia.
Core symptoms: depressed mood, loss of interest/pleasure, weight/appetite change,
insomnia or hypersomnia, psychomotor changes, fatigue, worthlessness or excessive guilt,
reduced concentration, recurrent thoughts of death or suicidal ideation.
PHQ-9: 0-4 minimal, 5-9 mild, 10-14 moderate, 15-19 moderately severe, 20-27 severe.

GENERALIZED ANXIETY DISORDER (GAD) — DSM-5
Excessive anxiety/worry more days than not for 6+ months about multiple topics.
3+ symptoms: restlessness, fatigue, poor concentration, irritability, muscle tension, sleep disturbance.
GAD-7: 0-4 minimal, 5-9 mild, 10-14 moderate, 15-21 severe.

PANIC DISORDER — DSM-5
Recurrent unexpected panic attacks. Symptoms: palpitations, sweating, trembling,
shortness of breath, chest pain, nausea, dizziness, derealization, fear of dying.

SOCIAL ANXIETY DISORDER — DSM-5
Marked fear in social situations involving scrutiny. Avoidance or intense distress.
SPIN: 0-20 none, 21-30 mild, 31-40 moderate, 41-50 severe, 51-68 very severe.

COGNITIVE BEHAVIORAL THERAPY
Core: Automatic Thoughts → Emotions → Behaviors. Distortions include: all-or-nothing thinking,
catastrophizing, mind reading, fortune telling, emotional reasoning, personalization.
Techniques: thought records, behavioral activation, exposure therapy, relaxation, problem-solving.

4-7-8 BREATHING: Activates vagal tone and parasympathetic response.
Inhale 4 counts, hold 7, exhale 8. Repeat 4 cycles. Evidence: Gerritsen & Band (2018).

5-4-3-2-1 GROUNDING: Sensory grounding interrupts anxiety spiral.
Five senses sequentially: 5 see, 4 touch, 3 hear, 2 smell, 1 taste.
Evidence: DBT (Linehan, 1993); trauma-focused CBT.

PROGRESSIVE MUSCLE RELAXATION: Systematically tense/release muscle groups.
Reduces physiological anxiety including heart rate and skin conductance.
Evidence: Jacobson (1938). Daily practice for 2+ weeks for lasting effect.

BEHAVIORAL ACTIVATION: Action precedes motivation. Schedule meaningful activities.
Break overwhelming tasks into very small steps. Evidence: Martell et al. (2010).

CRISIS ASSESSMENT: C-SSRS levels 1-5 from passive ideation to active plan with intent.
Any active ideation with plan = immediate intervention. Safety planning required.

PAKISTAN MENTAL HEALTH: 80%+ treatment gap. Stigma significant. Patients often present with
somatic symptoms (headache, fatigue, body pain). Religious coping is protective.
Crisis: Umang 0317-4288665 | Rozan 051-2890505 | Edhi 115.

THERAPEUTIC RELATIONSHIP: Strongest predictor of outcomes across all psychotherapies.
Core conditions: empathy, unconditional positive regard, genuineness (Rogers, 1957).

GAMIFICATION IN MENTAL HEALTH: Torres et al. (2023) — 35% engagement increase via badges.
Streaks, progress tracking, milestone celebrations improve adherence.

EMOTION RECOGNITION: Text-based using DistilBERT/RoBERTa on GoEmotions dataset.
Voice-based using RAVDESS/IEMOCAP with MFCC features.
"""
