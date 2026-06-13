# 🧠 OmniMind — AI Psychologist (Streamlit)
**Sukkur IBA University — FYDP**  
Team: Ibad Ur Rahman · Shafique Ahmed · Khalid Hussain  
Supervisor: Dr. Abdul Sattar Chan

---

## What This Does

A complete AI-powered mental health system you can run **with one command** in VS Code.
Tests all your FYDP objectives before Flutter integration.

| Page | What it shows |
|------|--------------|
| 💬 Session | Therapy chat with Dr. Mira (LLaMA 3 8B via Groq + RAG) |
| 📋 Assessments | Live PHQ-9, GAD-7, PSS-10, SPIN forms — filled from conversation |
| 📈 Progress | Score timeline, risk level, exercise log |
| 📊 Performance | Latency, tokens, ROUGE benchmark scores |

---

## Setup (4 commands, done once)

```bash
# 1. Create virtual environment
python -m venv venv

# 2. Activate
venv\Scripts\activate          # Windows
source venv/bin/activate       # Mac / Linux

# 3. Run setup (installs libs, downloads embedding model, builds RAG index)
python setup.py

# 4. Open .env → paste your FREE Groq key
# Key from: https://console.groq.com (1 minute to get)
```

---

## Run

```bash
streamlit run app.py
# Opens at: http://localhost:8501
```

---

## Project Structure

```
omnimind_streamlit/
├── app.py                  ← Run this (single entry point)
├── config.py               ← All settings
├── setup.py                ← One-time setup
├── requirements.txt
├── .env.example            ← Copy to .env, add Groq key
│
├── core/
│   ├── crisis.py           ← Crisis detection + helplines
│   ├── assessments.py      ← PHQ-9, GAD-7, PSS-10, SPIN
│   ├── exercises.py        ← 6 CBT exercises
│   ├── rag.py              ← FAISS + DSM-5 knowledge base
│   └── llm.py              ← LLaMA 3 8B + performance tracking
│
├── pages/
│   ├── chat_page.py        ← Therapy chat interface
│   ├── assessment_page.py  ← Live standardized forms
│   ├── progress_page.py    ← Progress charts
│   └── performance_page.py ← LLM metrics + ROUGE
│
└── data/
    └── clinical_knowledge.txt  ← Built-in clinical corpus
```

---

## FYDP Objectives — How This System Achieves Each

| Objective | How |
|-----------|-----|
| Real-time emotion detection from text | `core/llm.py` detects emotion per turn, shown in Performance tab |
| PHQ-9 depression screening | `core/assessments.py` — filled dynamically from conversation |
| GAD-7 anxiety screening | Same — 7 questions, auto-inferred + direct input available |
| PSS-10 stress screening | Same — 10 questions with reverse scoring |
| SPIN social anxiety | Same — 17 questions |
| Adaptive CBT interventions | 6 exercises offered based on dominant symptom domain |
| Progress tracking | Plotly charts over conversation turns |
| Crisis detection | Regex-based detection, immediate helplines |
| RAG with DSM-5 | FAISS + sentence-transformers + clinical knowledge base |
| LLM evaluation | Latency, tokens, ROUGE benchmark vs expert references |

---

## Adding DSM-5 PDFs (optional but improves RAG)

```bash
# Put PDF files in data/ folder:
# data/dsm5_depression.pdf
# data/cbt_manual.pdf

# Delete old index and rebuild:
rmdir /s cache      # Windows
rm -rf cache/       # Mac/Linux

python setup.py
```

---

## Disclaimer
Research prototype for academic purposes only.
Not a replacement for professional mental health care.
