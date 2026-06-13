"""
setup.py  —  OmniMind One-Time Setup
=====================================
Run ONCE before launching app.py for the first time.
"""
import sys, subprocess
from pathlib import Path


def run(cmd):
    print(f"  $ {cmd}")
    return subprocess.run(cmd, shell=True).returncode == 0


def main():
    print("\n" + "="*55)
    print("  OmniMind  —  Setup")
    print("="*55)

    v = sys.version_info
    if v.major != 3 or v.minor < 9:
        print(f"\n  ❌ Python 3.9+ required. You have {v.major}.{v.minor}")
        sys.exit(1)
    print(f"\n  ✓ Python {v.major}.{v.minor}.{v.micro}")

    # 1. Install dependencies
    print("\n[1/4] Installing dependencies…")
    if not run(f'"{sys.executable}" -m pip install -r requirements.txt -q'):
        print("  ⚠️  Some installs may have failed. Try: pip install -r requirements.txt")

    # 2. Create .env if missing
    env = Path(".env")
    if not env.exists():
        env.write_text(
            "GROQ_API_KEY=your_groq_api_key_here\n"
            "GROQ_MODEL=llama3-8b-8192\n"
        )
        print("\n[2/4] Created .env  ← OPEN THIS FILE and paste your Groq API key!")
        print("      Free key at: https://console.groq.com")
    else:
        print("\n[2/4] .env already exists ✓")

    # 3. Download embedding model
    print("\n[3/4] Downloading embedding model (22 MB, one time only)…")
    try:
        from sentence_transformers import SentenceTransformer
        SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
        print("  ✓ Embedding model ready")
    except Exception as e:
        print(f"  ⚠️  {e}")

    # 4. Build RAG index
    print("\n[4/4] Building clinical knowledge base…")
    try:
        from core.rag import RAGEngine
        e = RAGEngine()
        e.load()
        print(f"  ✓ RAG index built ({len(e.chunks)} chunks)")
    except Exception as e:
        print(f"  ⚠️  {e}")

    print("\n" + "="*55)
    print("  Setup complete!")
    print("="*55)
    print("""
  NEXT STEPS:
  ─────────────────────────────────────────────────
  1. Open .env  →  paste your Groq key
     (FREE at https://console.groq.com — takes 1 min)

  2. Launch the app:
     streamlit run app.py

  3. Browser opens at:
     http://localhost:8501

  Optional: add DSM-5 PDFs to data/ folder,
  then re-run setup.py to rebuild knowledge base.
  ─────────────────────────────────────────────────
""")


if __name__ == "__main__":
    main()
