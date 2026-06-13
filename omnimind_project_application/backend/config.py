"""config.py — single source of all settings."""
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR     = Path(__file__).parent
DATA_DIR     = BASE_DIR / "data"
CACHE_DIR    = BASE_DIR / "cache"
SESSIONS_DIR = BASE_DIR / "sessions"

for d in [DATA_DIR, CACHE_DIR, SESSIONS_DIR]:
    d.mkdir(exist_ok=True)

GROQ_API_KEY  = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL    = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")

EMBED_MODEL   = "sentence-transformers/all-MiniLM-L6-v2"
CHUNK_SIZE    = 600
CHUNK_OVERLAP = 80
TOP_K         = 5
INDEX_PATH    = CACHE_DIR / "faiss.index"
CHUNKS_PATH   = CACHE_DIR / "chunks.pkl"

MAX_TOKENS    = 500
TEMPERATURE   = 0.65
HISTORY_KEEP  = 8
