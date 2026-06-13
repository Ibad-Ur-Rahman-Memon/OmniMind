"""pages/chat_page.py — Therapy chat with Dr. Mira."""
import streamlit as st
from core.crisis import check_crisis
from core.exercises import EXERCISES, get_exercises_for_domain


OPENING = (
    "Hello, I'm Dr. Mira. I'm genuinely glad you're here today. "
    "This is a completely safe and confidential space — you can share whatever is on your mind, "
    "at your own pace, without any judgment at all.\n\n"
    "To start us off — how have you been feeling lately?"
)


def render(session, llm, rag, assessment_mgr):
    # ── Header ─────────────────────────────────────────────────────────────────
    col1, col2, col3 = st.columns([3, 1, 1])
    with col1:
        st.markdown("### 💬 Session with Dr. Mira")
    with col2:
        risk = assessment_mgr.overall_risk()
        color = {"low": "🟢", "moderate": "🟡", "high": "🔴"}.get(risk, "⚪")
        st.caption(f"Risk: {color} {risk.upper()}")
    with col3:
        st.caption(f"Turn {session['turn_count']}")

    # ── Init session state ─────────────────────────────────────────────────────
    if "exercise_active"  not in st.session_state:
        st.session_state.exercise_active  = False
    if "exercise_id"      not in st.session_state:
        st.session_state.exercise_id      = None
    if "exercise_step"    not in st.session_state:
        st.session_state.exercise_step    = 0
    if "post_exercise"    not in st.session_state:
        st.session_state.post_exercise    = False
    if "offer_exercise"   not in st.session_state:
        st.session_state.offer_exercise   = None
    if "initial_shown"    not in st.session_state:
        st.session_state.initial_shown    = False

    # ── Opening message ────────────────────────────────────────────────────────
    # Use only initial_shown flag to prevent duplicates - don't check history
    if not st.session_state.initial_shown:
        with st.chat_message("assistant", avatar="🧠"):
            st.markdown(OPENING)
        session["history"].append({"role": "assistant", "content": OPENING})
        st.session_state.initial_shown = True

    # ── Chat history ───────────────────────────────────────────────────────────
    for msg in session["history"]:
        avatar = "🧠" if msg["role"] == "assistant" else "🫂"
        with st.chat_message(msg["role"], avatar=avatar):
            st.markdown(msg["content"])

    # ── Exercise panel (replaces chat input while active) ──────────────────────
    if st.session_state.exercise_active:
        _exercise_panel(session, llm, assessment_mgr)
        return

    # ── Exercise offer banner ──────────────────────────────────────────────────
    if st.session_state.offer_exercise:
        ex = st.session_state.offer_exercise
        st.info(
            f"**Dr. Mira suggests:** *{ex.name}* — {ex.tagline} (~{ex.duration_min} min)",
            icon="🌿",
        )
        c1, c2 = st.columns(2)
        if c1.button("✓  Yes, let's try it", use_container_width=True, type="primary"):
            st.session_state.exercise_active = True
            st.session_state.exercise_id     = ex.id
            st.session_state.exercise_step   = 0
            st.session_state.offer_exercise  = None
            st.rerun()
        if c2.button("Not right now", use_container_width=True):
            st.session_state.offer_exercise = None
            st.rerun()

    # ── Chat input ─────────────────────────────────────────────────────────────
    user_input = st.chat_input("Share what's on your mind…")
    if not user_input:
        return

    with st.chat_message("user", avatar="🫂"):
        st.markdown(user_input)
    session["history"].append({"role": "user", "content": user_input})
    session["turn_count"] += 1
    st.session_state.offer_exercise = None

    # ── Crisis check ───────────────────────────────────────────────────────────
    crisis = check_crisis(user_input)
    if crisis.detected:
        llm.tracker.crisis_events += 1
        with st.chat_message("assistant", avatar="🧠"):
            st.error("⚠️ I'm very concerned about your safety right now.", icon="🆘")
            st.markdown(crisis.message)
        session["history"].append({"role": "assistant", "content": crisis.message})
        _save(session)
        st.rerun()
        return

    # ── Assessment update ──────────────────────────────────────────────────────
    assessment_mgr.update_from_text(user_input)

    # ── RAG ───────────────────────────────────────────────────────────────────
    rag_context, rag_used = rag.retrieve(user_input)

    # ── LLM ───────────────────────────────────────────────────────────────────
    with st.chat_message("assistant", avatar="🧠"):
        with st.spinner("Dr. Mira is responding…"):
            result = llm.generate(
                user_message=user_input,
                history=session["history"][:-1],
                rag_context=rag_context,
                assessment_summary=assessment_mgr.summary_for_llm(),
                post_exercise=st.session_state.post_exercise,
            )
        st.markdown(result["reply"])

        # Tiny metrics badge
        col_a, col_b, col_c = st.columns(3)
        col_a.caption(f"⏱ {result['latency_ms']:.0f} ms")
        col_b.caption(f"🔍 RAG: {'✓' if result['rag_used'] else '✗'}")
        col_c.caption(f"💭 {result['emotion']}")

    st.session_state.post_exercise = False
    session["history"].append({"role": "assistant", "content": result["reply"]})
    session["perf_rows"] = llm.tracker.all_rows()

    # ── Progress snapshot every 3 turns ──────────────────────────────────────
    if session["turn_count"] % 3 == 0:
        session["progress"].append({
            "turn":   session["turn_count"],
            "PHQ-9":  assessment_mgr.phq9.total_score(),
            "GAD-7":  assessment_mgr.gad7.total_score(),
            "PSS-10": assessment_mgr.pss10.total_score(),
            "SPIN":   assessment_mgr.spin.total_score(),
            "risk":   assessment_mgr.overall_risk(),
        })

    # ── Exercise suggestion every 4 turns ─────────────────────────────────────
    if session["turn_count"] % 4 == 0 and session["turn_count"] >= 4:
        domain   = assessment_mgr.dominant_domain()
        done_ids = {e["id"] for e in session["exercises_done"]}
        for ex in get_exercises_for_domain(domain):
            if ex.id not in done_ids:
                st.session_state.offer_exercise = ex
                llm.tracker.exercises_triggered += 1
                break

    _save(session)
    st.rerun()


def _exercise_panel(session, llm, assessment_mgr):
    ex_id = st.session_state.exercise_id
    ex    = EXERCISES.get(ex_id)
    if not ex:
        st.session_state.exercise_active = False
        st.rerun()
        return

    # Initialize exercise responses storage
    if "exercise_responses" not in st.session_state:
        st.session_state.exercise_responses = {}

    step  = st.session_state.exercise_step
    steps = ex.steps
    total = len(steps)

    st.markdown(f"### 🌿 {ex.name}")
    st.caption(ex.tagline)
    st.progress(step / total if total else 0)

    # Intro on step 0
    if step == 0:
        with st.chat_message("assistant", avatar="🧠"):
            st.markdown(ex.intro_message)
        session["history"].append({"role": "assistant", "content": ex.intro_message})
        session["exercises_done"].append({"id": ex.id, "name": ex.name, "completed": False})
        # Initialize responses for this exercise
        st.session_state.exercise_responses[ex_id] = {}

    # Current step with input collection
    if step < total:
        st.markdown(f"**Step {step + 1} of {total}:**")
        st.markdown(steps[step])

        # Get current response if exists
        current_resp = st.session_state.exercise_responses.get(ex_id, {}).get(step, "")

        # Show previous responses
        if step > 0:
            with st.expander("📝 View your responses so far"):
                for i in range(step):
                    resp_text = st.session_state.exercise_responses.get(ex_id, {}).get(i, "")
                    if resp_text:
                        st.markdown(f"**Step {i+1}:** {resp_text}")

        # Input field for user response
        if ex_id == "thought_record":
            # Special handling for Thought Record - each step needs user input
            resp_key = f"resp_{ex_id}_{step}"
            user_input = st.text_area(
                "Your response:",
                value=current_resp,
                height=100,
                key=resp_key,
                placeholder="Enter your response here..."
            )

            # Save the response
            if st.session_state.exercise_responses.get(ex_id, {}) != {}:
                if ex_id not in st.session_state.exercise_responses:
                    st.session_state.exercise_responses[ex_id] = {}
                st.session_state.exercise_responses[ex_id][step] = user_input
        else:
            # For other exercises, just advance without requiring input
            user_input = current_resp

        c1, c2 = st.columns([1, 2])
        if c1.button("Stop exercise"):
            st.session_state.exercise_active = False
            st.session_state.exercise_step   = 0
            st.rerun()

        # For Thought Record, require input before proceeding
        if ex_id == "thought_record":
            if c2.button("Next step →", type="primary"):
                # Save the response before moving on
                st.session_state.exercise_responses[ex_id][step] = user_input
                st.session_state.exercise_step += 1
                st.rerun()
        else:
            if c2.button("Next step →", type="primary"):
                st.session_state.exercise_step += 1
                st.rerun()
    else:
        # Complete - show all responses
        st.success("✅  Exercise complete! Well done for taking that time for yourself.")

        # Display all collected responses for Thought Record
        if ex_id == "thought_record" and ex_id in st.session_state.exercise_responses:
            st.markdown("### 📋 Your Thought Record")
            responses = st.session_state.exercise_responses[ex_id]
            step_labels = [
                "Situation",
                "Automatic Thought",
                "Emotions",
                "Evidence FOR",
                "Evidence AGAINST",
                "Balanced Thought",
                "Re-rated Emotions"
            ]
            for i, label in enumerate(step_labels):
                resp = responses.get(i, "")
                if resp:
                    st.markdown(f"**{label}:** {resp}")
            st.markdown("---")

        feedback = st.text_area(
            "What did you notice during the exercise?",
            placeholder="Share anything you felt or observed…",
            key="ex_feedback",
        )
        if st.button("Continue session →", type="primary"):
            # Build summary from responses
            if ex_id == "thought_record" and ex_id in st.session_state.exercise_responses:
                responses = st.session_state.exercise_responses[ex_id]
                summary_parts = []
                step_labels = [
                    "Situation", "Automatic Thought", "Emotions",
                    "Evidence FOR", "Evidence AGAINST", "Balanced Thought", "Re-rated Emotions"
                ]
                for i, label in enumerate(step_labels):
                    resp = responses.get(i, "")
                    if resp:
                        summary_parts.append(f"{label}: {resp}")
                fb_text = feedback.strip() or " ".join(summary_parts)
            else:
                fb_text = feedback.strip() or "I just finished the exercise."

            # Mark complete
            for e in reversed(session["exercises_done"]):
                if e["id"] == ex_id and not e["completed"]:
                    e["completed"] = True
                    e["feedback"]  = feedback
                    break

            # Post-exercise LLM reply
            result  = llm.generate(
                user_message=fb_text,
                history=session["history"],
                rag_context="",
                assessment_summary=assessment_mgr.summary_for_llm(),
                post_exercise=True,
            )
            session["history"].append({"role": "user",      "content": fb_text})
            session["history"].append({"role": "assistant", "content": result["reply"]})
            session["perf_rows"] = llm.tracker.all_rows()

            st.session_state.exercise_active  = False
            st.session_state.exercise_step    = 0
            st.session_state.post_exercise    = True
            # Clear exercise responses
            st.session_state.exercise_responses = {}
            _save(session)
            st.rerun()


def _save(session):
    import json, uuid
    from config import SESSIONS_DIR
    sid  = session.get("session_id", str(uuid.uuid4()))
    path = SESSIONS_DIR / f"{sid}.json"
    safe = {k: v for k, v in session.items()}
    with open(path, "w") as f:
        json.dump(safe, f, indent=2, default=str)
