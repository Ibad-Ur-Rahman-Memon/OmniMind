"""pages/progress_page.py — Patient progress over session."""
import streamlit as st
import plotly.graph_objects as go
import pandas as pd


def render(session, assessment_mgr):
    st.markdown("### 📈 Patient Progress Tracking")

    if not session["progress"]:
        st.info(
            "Progress charts appear after 3 conversation turns. "
            "Keep chatting with Dr. Mira — your progress will appear here automatically.",
            icon="📊",
        )
        return

    df = pd.DataFrame(session["progress"])

    # ── Score timeline ────────────────────────────────────────────────────────
    st.subheader("Assessment scores over time")
    cols = ["PHQ-9", "GAD-7", "PSS-10", "SPIN"]
    colors = {"PHQ-9": "#534AB7", "GAD-7": "#D85A30", "PSS-10": "#BA7517", "SPIN": "#185FA5"}

    fig = go.Figure()
    for col in cols:
        if col in df.columns:
            fig.add_trace(go.Scatter(
                x=df["turn"], y=df[col],
                mode="lines+markers",
                name=col,
                line=dict(color=colors[col], width=2.5),
                marker=dict(size=8),
            ))
    fig.update_layout(
        xaxis_title="Conversation turn",
        yaxis_title="Score",
        legend=dict(orientation="h", y=1.1),
        margin=dict(l=0, r=0, t=20, b=0),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        height=320,
    )
    fig.update_xaxes(gridcolor="rgba(128,128,128,0.15)")
    fig.update_yaxes(gridcolor="rgba(128,128,128,0.15)")
    st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # ── Current vs start ──────────────────────────────────────────────────────
    st.subheader("Score comparison: start vs current")
    first = df.iloc[0]
    last  = df.iloc[-1]

    c_cols = st.columns(4)
    for c, name in zip(c_cols, cols):
        if name in df.columns:
            start_v = int(first.get(name, 0))
            curr_v  = int(last.get(name,  0))
            delta   = curr_v - start_v
            c.metric(name, curr_v, delta=delta,
                     delta_color="inverse" if delta <= 0 else "normal")

    st.divider()

    # ── Risk timeline ─────────────────────────────────────────────────────────
    st.subheader("Risk level over time")
    risk_map = {"low": 1, "moderate": 2, "high": 3, "unknown": 0}
    if "risk" in df.columns:
        df["risk_num"] = df["risk"].map(risk_map).fillna(0)
        fig2 = go.Figure(go.Scatter(
            x=df["turn"], y=df["risk_num"],
            mode="lines+markers",
            line=dict(color="#E05A3A", width=2),
            marker=dict(size=9),
            hovertext=df["risk"],
        ))
        fig2.update_layout(
            xaxis_title="Turn",
            yaxis=dict(tickvals=[0,1,2,3], ticktext=["unknown","low","moderate","high"]),
            margin=dict(l=0, r=0, t=10, b=0),
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            height=200,
        )
        st.plotly_chart(fig2, use_container_width=True)

    st.divider()

    # ── Exercises done ────────────────────────────────────────────────────────
    st.subheader("Exercises in this session")
    if session["exercises_done"]:
        for ev in session["exercises_done"]:
            icon   = "✅" if ev.get("completed") else "⏳"
            status = "Completed" if ev.get("completed") else "In progress"
            with st.expander(f"{icon} {ev['name']} — {status}"):
                if ev.get("feedback"):
                    st.markdown(f"**Patient's feedback:** {ev['feedback']}")
    else:
        st.caption("No exercises completed yet. They appear automatically during the session.")

    st.divider()

    # ── Session stats ─────────────────────────────────────────────────────────
    st.subheader("Session statistics")
    sc1, sc2, sc3, sc4 = st.columns(4)
    sc1.metric("Turns (user)",     session["turn_count"])
    sc2.metric("Progress points",  len(session["progress"]))
    sc3.metric("Exercises done",   sum(1 for e in session["exercises_done"] if e.get("completed")))
    sc4.metric("Dominant domain",  assessment_mgr.dominant_domain().title())
