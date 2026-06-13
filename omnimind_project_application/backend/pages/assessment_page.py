"""pages/assessment_page.py — Live standardized assessment forms."""
import streamlit as st
import plotly.graph_objects as go
import pandas as pd


SEV_COLOR = {
    "Minimal": "#4CAF50", "No ": "#4CAF50", "Low": "#4CAF50",
    "Mild":    "#8BC34A",
    "Moderate":"#FFC107",
    "Moderately severe": "#FF9800",
    "Severe":  "#F44336", "Very severe": "#B71C1C", "High": "#F44336",
}

def _color(sev: str) -> str:
    for k, v in SEV_COLOR.items():
        if sev.startswith(k):
            return v
    return "#9E9E9E"


def render(assessment_mgr, session):
    st.markdown("### 📋 Clinical Assessments")
    st.caption(
        "Answers are filled automatically from the conversation using AI inference. "
        "Confidence % shows how certain the inference is. "
        "You can also directly fill any question by expanding it."
    )

    # ── Overall risk banner ────────────────────────────────────────────────────
    risk = assessment_mgr.overall_risk()
    if risk == "high":
        st.error("⚠️  Overall risk level: HIGH — consider professional referral", icon="🔴")
    elif risk == "moderate":
        st.warning("Overall risk level: MODERATE — monitor closely", icon="🟡")
    elif risk == "low":
        st.success("Overall risk level: LOW", icon="🟢")

    tabs = st.tabs(["PHQ-9", "GAD-7", "PSS-10", "SPIN", "📊 Summary"])

    with tabs[0]:
        _form(assessment_mgr.phq9, assessment_mgr)
    with tabs[1]:
        _form(assessment_mgr.gad7, assessment_mgr)
    with tabs[2]:
        _form(assessment_mgr.pss10, assessment_mgr)
    with tabs[3]:
        _form(assessment_mgr.spin, assessment_mgr)
    with tabs[4]:
        _summary(assessment_mgr)


def _form(a, mgr):
    sev, _  = a.severity()
    color   = _color(sev)
    score   = a.total_score()
    pct     = round(a.completion_pct(), 0)

    # Score header
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Score",      score)
    c2.metric("Severity",   sev)
    c3.metric("Answered",   f"{a.answered_count()}/{len(a.questions)}")
    c4.metric("Completion", f"{pct:.0f}%")

    # Interpretation banner
    st.markdown(
        f"<div style='background:{color}22;border-left:4px solid {color};"
        f"padding:10px 14px;border-radius:0 8px 8px 0;font-size:13px;margin:8px 0 12px'>"
        f"<strong>{sev}</strong> — {a.interpretation_text()}</div>",
        unsafe_allow_html=True,
    )

    st.markdown(f"**{a.full_name}** — {a.domain}")

    # Progress bar
    st.progress(pct / 100)
    st.caption(f"{a.answered_count()} of {len(a.questions)} questions answered from conversation")

    st.divider()

    # Questions
    for q in a.questions:
        active = q.active_score()
        source = ""
        if q.direct_score is not None:
            source = f"✏️ Direct"
        elif q.inferred_score is not None:
            source = f"🔍 Inferred ({int(q.confidence*100)}% confidence)"

        label_preview = f"— **{q.option_label()}** {source}" if active is not None else "— *not yet answered*"

        with st.expander(f"**{q.id}:** {q.text}  {label_preview}", expanded=False):
            choice = st.radio(
                "Select answer:",
                options=list(range(len(q.options))),
                format_func=lambda i, qq=q: f"{qq.options[i]}  (score: {qq.scores[i]})",
                index=active if active is not None else 0,
                key=f"radio_{a.name}_{q.id}",
            )
            if st.button("✓ Set this answer", key=f"btn_{a.name}_{q.id}"):
                mgr.set_direct(a.name, q.id, q.scores[choice])
                st.success(f"Recorded: {q.options[choice]}")
                st.rerun()

            if q.keywords:
                st.caption(f"Detected from conversation if patient mentions: "
                           f"{', '.join(q.keywords[:5])}…")


def _summary(mgr):
    st.markdown("#### Summary across all assessments")

    rows = []
    for a in mgr.all:
        sev, color = a.severity()
        rows.append({
            "Assessment": a.full_name,
            "Domain":     a.domain,
            "Score":      a.total_score(),
            "Severity":   sev,
            "Answered":   f"{a.answered_count()}/{len(a.questions)}",
            "Complete":   f"{a.completion_pct():.0f}%",
        })

    st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)

    # Radar chart
    if any(a.answered_count() > 0 for a in mgr.all):
        st.divider()
        st.markdown("#### Emotional profile radar")
        radar = mgr.radar_data()
        labels = list(radar.keys())
        values = list(radar.values())

        fig = go.Figure(data=go.Scatterpolar(
            r=values + [values[0]],
            theta=labels + [labels[0]],
            fill="toself",
            fillcolor="rgba(83,74,183,0.18)",
            line=dict(color="#534AB7", width=2.5),
            marker=dict(size=7),
        ))
        fig.update_layout(
            polar=dict(radialaxis=dict(visible=True, range=[0, 100])),
            showlegend=False,
            margin=dict(l=60, r=60, t=40, b=40),
            paper_bgcolor="rgba(0,0,0,0)",
            height=380,
        )
        st.plotly_chart(fig, use_container_width=True)

        # Score cards
        cols = st.columns(4)
        for col, a in zip(cols, mgr.all):
            sev, _ = a.severity()
            col.metric(a.name, a.total_score(), delta=sev, delta_color="off")
