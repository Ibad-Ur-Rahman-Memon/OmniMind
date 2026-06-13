"""pages/performance_page.py — LLM performance monitoring and ROUGE evaluation."""
import streamlit as st
import plotly.graph_objects as go
import pandas as pd
from config import GROQ_MODEL


REFERENCE_QA = [
    {"input": "I have been feeling really sad and hopeless for weeks.",
     "reference": "I hear you — feeling persistently low for weeks is genuinely exhausting, and it takes courage to name it. Sometimes our emotions carry signals that need our attention. How long have you been experiencing this sadness?"},
    {"input": "I can't stop worrying about everything. My mind just races constantly.",
     "reference": "A racing mind that won't stop is one of the most draining experiences — it exhausts you without ever resolving anything. Worry often feels like it's protecting us, even when it isn't. What kinds of things are you worrying about most?"},
    {"input": "I feel completely overwhelmed. There is just too much going on.",
     "reference": "When everything feels like too much at once, it can be hard to even know where to begin. That kind of overwhelm is a real signal worth taking seriously. If you had to name the one thing weighing on you most heavily right now, what would it be?"},
    {"input": "I avoid social situations because I am scared of being judged.",
     "reference": "That fear of judgment is something many people experience more deeply than they show. Avoiding situations provides relief in the moment, but often makes the fear stronger over time. Can you tell me about a specific situation you've been avoiding lately?"},
    {"input": "I feel hopeless. Nothing is ever going to get better for me.",
     "reference": "Thank you for trusting me with something this heavy. Hopelessness can make the future feel like a locked door — and that is an exhausting place to be. When did things start feeling this hopeless for you?"},
]


def render(session, llm):
    st.markdown("### 📊 LLM Performance Monitor")
    st.caption(f"Model: **{GROQ_MODEL}** via Groq API · Real-time tracking")

    rows = session.get("perf_rows", [])

    if not rows:
        st.info(
            "Performance data appears after the first LLM response. "
            "Go to the Session tab and send a message to Dr. Mira.",
            icon="💡",
        )
        return

    summary = llm.tracker.summary()

    # ── Summary metric cards ──────────────────────────────────────────────────
    st.subheader("Session performance summary")
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("API calls",         summary.get("total_calls", 0))
    c2.metric("Avg latency",       f"{summary.get('avg_latency_ms',0):.0f} ms")
    c3.metric("Min latency",       f"{summary.get('min_latency_ms',0):.0f} ms")
    c4.metric("Max latency",       f"{summary.get('max_latency_ms',0):.0f} ms")
    c5.metric("Total tokens used", summary.get("total_tokens_used", 0))

    c6, c7, c8 = st.columns(3)
    c6.metric("Avg prompt tokens",     f"{summary.get('avg_prompt_tokens',0):.0f}")
    c7.metric("Avg completion tokens", f"{summary.get('avg_completion_tokens',0):.0f}")
    c8.metric("Crisis events",         summary.get("crisis_events", 0))

    st.divider()

    df = pd.DataFrame(rows)

    # ── Latency chart ─────────────────────────────────────────────────────────
    st.subheader("Response latency per turn")
    fig_lat = go.Figure()
    fig_lat.add_trace(go.Scatter(
        x=df["turn"], y=df["latency_ms"],
        mode="lines+markers",
        name="Latency (ms)",
        line=dict(color="#534AB7", width=2.5),
        marker=dict(size=8),
    ))
    if len(df) > 1:
        avg_lat = df["latency_ms"].mean()
        fig_lat.add_hline(y=avg_lat, line_dash="dash", line_color="#D85A30",
                          annotation_text=f"Mean: {avg_lat:.0f} ms")
    fig_lat.update_layout(
        xaxis_title="Turn", yaxis_title="Latency (ms)",
        margin=dict(l=0, r=0, t=20, b=0),
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        height=260,
    )
    fig_lat.update_xaxes(gridcolor="rgba(128,128,128,0.15)")
    fig_lat.update_yaxes(gridcolor="rgba(128,128,128,0.15)")
    st.plotly_chart(fig_lat, use_container_width=True)

    st.divider()

    # ── Token usage chart ─────────────────────────────────────────────────────
    st.subheader("Token usage per turn")
    fig_tok = go.Figure()
    fig_tok.add_trace(go.Bar(x=df["turn"], y=df["prompt_tokens"],
                             name="Prompt tokens", marker_color="#B5D4F4"))
    fig_tok.add_trace(go.Bar(x=df["turn"], y=df["completion_tokens"],
                             name="Completion tokens", marker_color="#534AB7"))
    fig_tok.update_layout(
        barmode="stack", xaxis_title="Turn", yaxis_title="Tokens",
        legend=dict(orientation="h", y=1.1),
        margin=dict(l=0, r=0, t=20, b=0),
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        height=260,
    )
    st.plotly_chart(fig_tok, use_container_width=True)

    st.divider()

    # ── Emotion distribution ──────────────────────────────────────────────────
    st.subheader("Detected emotion distribution")
    emo_dist = llm.tracker.emotion_dist()
    if emo_dist:
        emo_df = pd.DataFrame(
            {"Emotion": list(emo_dist.keys()), "Count": list(emo_dist.values())}
        ).sort_values("Count", ascending=False)
        fig_emo = go.Figure(go.Bar(
            x=emo_df["Emotion"], y=emo_df["Count"],
            marker_color="#D85A30",
        ))
        fig_emo.update_layout(
            xaxis_title="Emotion", yaxis_title="Turns",
            margin=dict(l=0, r=0, t=10, b=0),
            paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
            height=220,
        )
        st.plotly_chart(fig_emo, use_container_width=True)

    st.divider()

    # ── RAG usage ─────────────────────────────────────────────────────────────
    st.subheader("RAG retrieval usage")
    if "rag_used" in df.columns:
        rag_yes = df["rag_used"].sum()
        rag_no  = len(df) - rag_yes
        col_r1, col_r2 = st.columns(2)
        col_r1.metric("Turns with RAG", rag_yes)
        col_r2.metric("Turns without RAG", rag_no)
        st.caption("RAG = DSM-5 knowledge retrieved and injected into the LLM prompt for that turn.")

    st.divider()

    # ── Raw metrics table ─────────────────────────────────────────────────────
    with st.expander("📄 Raw metrics table (all turns)"):
        st.dataframe(
            df[["turn","latency_ms","prompt_tokens","completion_tokens",
                "response_length","rag_used","emotion"]],
            use_container_width=True,
        )

    st.divider()

    # ── ROUGE Benchmark ───────────────────────────────────────────────────────
    st.subheader("🎯 ROUGE Quality Benchmark")
    st.markdown(
        "This benchmark sends **5 standardized mental health questions** to the LLM "
        "and compares its responses to expert-authored reference answers using ROUGE scores. "
        "Use this in your **thesis documentation** to show model performance."
    )

    if st.button("▶  Run ROUGE Benchmark  (takes ~15 seconds)", type="primary"):
        try:
            from rouge_score import rouge_scorer
            scorer = rouge_scorer.RougeScorer(["rouge1","rouge2","rougeL"], use_stemmer=True)
        except ImportError:
            st.error("Install rouge-score: pip install rouge-score")
            return

        results = []
        progress = st.progress(0, "Running benchmark…")
        for i, qa in enumerate(REFERENCE_QA):
            progress.progress((i+1) / len(REFERENCE_QA), f"Question {i+1}/{len(REFERENCE_QA)}…")
            gen = llm.generate(user_message=qa["input"], history=[], rag_context="", assessment_summary="")
            scores = scorer.score(qa["reference"], gen["reply"])
            results.append({
                "Question":       qa["input"][:60] + "…",
                "Generated":      gen["reply"][:120] + "…",
                "ROUGE-1":        round(scores["rouge1"].fmeasure, 4),
                "ROUGE-2":        round(scores["rouge2"].fmeasure, 4),
                "ROUGE-L":        round(scores["rougeL"].fmeasure, 4),
                "Latency (ms)":   gen["latency_ms"],
            })
        progress.empty()

        res_df = pd.DataFrame(results)
        avgs = {
            "ROUGE-1": round(res_df["ROUGE-1"].mean(), 4),
            "ROUGE-2": round(res_df["ROUGE-2"].mean(), 4),
            "ROUGE-L": round(res_df["ROUGE-L"].mean(), 4),
            "Avg Latency": f"{res_df['Latency (ms)'].mean():.0f} ms",
        }

        st.success("Benchmark complete!")
        st.markdown("#### Average ROUGE Scores")
        bc1, bc2, bc3, bc4 = st.columns(4)
        bc1.metric("ROUGE-1", avgs["ROUGE-1"],
                   help="Unigram overlap. >0.30 is good for conversational therapy.")
        bc2.metric("ROUGE-2", avgs["ROUGE-2"],
                   help="Bigram overlap. >0.12 indicates vocabulary alignment.")
        bc3.metric("ROUGE-L", avgs["ROUGE-L"],
                   help="Longest common subsequence. >0.25 indicates structural similarity.")
        bc4.metric("Avg Latency", avgs["Avg Latency"])

        st.markdown("#### Per-question breakdown")
        st.dataframe(res_df, use_container_width=True, hide_index=True)

        # Bar chart
        fig_r = go.Figure()
        for metric, color in [("ROUGE-1","#534AB7"),("ROUGE-2","#D85A30"),("ROUGE-L","#0F6E56")]:
            fig_r.add_trace(go.Bar(
                x=[f"Q{i+1}" for i in range(len(results))],
                y=res_df[metric],
                name=metric, marker_color=color,
            ))
        fig_r.update_layout(
            barmode="group", xaxis_title="Question", yaxis_title="F1 Score",
            legend=dict(orientation="h", y=1.1),
            margin=dict(l=0, r=0, t=20, b=0),
            paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
            height=280,
        )
        st.plotly_chart(fig_r, use_container_width=True)

        st.info(
            "**For thesis documentation:** These ROUGE scores compare LLaMA 3 8B responses "
            "against expert-authored psychologist reference responses. After fine-tuning, "
            "run this again to compare before/after scores.",
            icon="📝",
        )
