"""
app.py  —  OmniMind Streamlit Application
==========================================
Single command to run everything:
    streamlit run app.py

No separate server needed. Everything runs in one process.
"""

import uuid
import streamlit as st
from config import GROQ_MODEL

# ── Page config (must be first Streamlit call) ────────────────────────────────
st.set_page_config(
    page_title="OmniMind — AI Psychologist",
    page_icon="🧠",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Minimal CSS ───────────────────────────────────────────────────────────────
st.markdown("""
<style>
[data-testid="stChatMessage"] { padding: 0.5rem 0; }
[data-testid="stSidebar"]     { padding-top: 1rem; }
div[data-testid="metric-container"] { background: var(--background-color); }
</style>
""", unsafe_allow_html=True)


# ── Cached resource loading ───────────────────────────────────────────────────

@st.cache_resource(show_spinner="Loading clinical knowledge base (first time only)…")
def _load_rag():
    from core.rag import RAGEngine
    engine = RAGEngine()
    engine.load()
    return engine


@st.cache_resource(show_spinner="Connecting to LLM (LLaMA 3 8B via Groq)…")
def _load_llm():
    from core.llm import LLMClient
    return LLMClient()


# ── Session state bootstrap ───────────────────────────────────────────────────

def _init_session():
    """Create a fresh session dict."""
    return {
        "session_id":    str(uuid.uuid4()),
        "history":       [],
        "turn_count":    0,
        "progress":      [],
        "exercises_done": [],
        "perf_rows":     [],
    }


if "session"        not in st.session_state:
    st.session_state.session        = _init_session()
if "assessment_mgr" not in st.session_state:
    from core.assessments import AssessmentManager
    st.session_state.assessment_mgr = AssessmentManager()


# ── Load engines ──────────────────────────────────────────────────────────────
try:
    rag = _load_rag()
except Exception as e:
    st.error(f"RAG engine failed: {e}")
    st.info("Run `python setup.py` first, then restart.")
    st.stop()

try:
    llm = _load_llm()
except RuntimeError as e:
    st.error(str(e))
    st.markdown("""
**To fix this:**
1. Open `.env` file in the project folder
2. Replace `your_groq_api_key_here` with your actual key
3. Get a **FREE** key at [console.groq.com](https://console.groq.com) (takes 1 minute)
4. Restart the app: `streamlit run app.py`
""")
    st.stop()

session        = st.session_state.session
assessment_mgr = st.session_state.assessment_mgr


# ── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown("## 🧠 OmniMind")
    st.caption("AI Mental Health Assessment System")
    st.caption("Sukkur IBA University — FYDP")
    st.divider()

    page = st.radio(
        "Navigation",
        ["💬  Session", "📋  Assessments", "📈  Progress", "📊  Performance"],
        label_visibility="collapsed",
    )

    st.divider()

    # Risk indicator
    risk  = assessment_mgr.overall_risk()
    icons = {"low": "🟢", "moderate": "🟡", "high": "🔴", "unknown": "⚪"}
    st.markdown(f"**Risk level:** {icons.get(risk,'⚪')} {risk.upper()}")
    st.caption(f"Session ID: `{session['session_id'][:12]}…`")
    st.caption(f"Turns: {session['turn_count']}")

    st.divider()

    # New session button
    if st.button("🔄  New Session", use_container_width=True):
        from core.assessments import AssessmentManager
        st.session_state.session        = _init_session()
        st.session_state.assessment_mgr = AssessmentManager()
        # Clear exercise state
        for key in ["exercise_active","exercise_id","exercise_step",
                    "post_exercise","offer_exercise","initial_shown",
                    "exercise_responses"]:
            st.session_state.pop(key, None)
        st.cache_resource.clear()
        st.rerun()

    st.divider()
    
    # ── Diagnostics ─────────────────────────────────────────────────────────────
    try:
        import groq
        import httpx
        st.caption(f"Groq: **{groq.__version__}** · httpx: **{httpx.__version__}**")
        st.caption(f"Model: `{GROQ_MODEL}`")
    except Exception:
        pass

    st.divider()
    st.caption("Supervisor: Dr. Abdul Sattar Chan")
    st.caption("Team: Ibad · Shafique · Khalid")


# ── Page routing ──────────────────────────────────────────────────────────────
if page == "💬  Session":
    from pages.chat_page import render
    render(session, llm, rag, assessment_mgr)

elif page == "📋  Assessments":
    from pages.assessment_page import render
    render(assessment_mgr, session)

elif page == "📈  Progress":
    from pages.progress_page import render
    render(session, assessment_mgr)

elif page == "📊  Performance":
    from pages.performance_page import render
    render(session, llm)
