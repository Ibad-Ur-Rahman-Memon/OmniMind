# OmniMind — Complete Setup Guide
**AI-Powered Mental Health Monitoring System**  
Sukkur IBA University | Final Year Design Project  
Supervisor: Dr. Abdul Sattar Chan | Team: Ibad Ur Rahman · Shafique Ahmed · Khalid Hussain

---

## Project Architecture Overview

```
OmniMind
├── backend/                   ← Python FastAPI server (wraps RAG + LLaMA 3)
│   ├── api_server.py          ← REST API entry point  ★ NEW
│   ├── api_requirements.txt   ← API-specific Python deps
│   ├── core/
│   │   ├── llm.py             ← Groq LLaMA 3 client
│   │   ├── rag.py             ← FAISS vector store + retrieval
│   │   ├── assessments.py     ← PHQ-9, GAD-7, PSS scoring
│   │   ├── exercises.py       ← CBT exercise definitions
│   │   └── crisis.py          ← Crisis keyword detection
│   ├── data/                  ← PDF knowledge base (DSM-5-TR etc.)
│   └── .env.example           ← Environment variable template
│
└── flutter_app/omnimind/      ← Flutter mobile application
    ├── lib/
    │   ├── main.dart
    │   ├── core/
    │   │   ├── models/        ← AppUser, ChatMessage, Assessment, etc.
    │   │   ├── services/      ← ApiService, AuthService, FirestoreService
    │   │   └── providers/     ← AuthProvider, ChatProvider, ThemeProvider
    │   ├── features/
    │   │   ├── auth/          ← SplashScreen, LoginScreen
    │   │   ├── chat/          ← ChatScreen (core AI interaction)
    │   │   ├── dashboard/     ← PatientDashboard, PatientHome
    │   │   ├── exercises/     ← ExercisesLibrary, ExercisePopup
    │   │   ├── assessments/   ← AssessmentScreen (PHQ-9, GAD-7, PSS)
    │   │   ├── diary/         ← DiaryScreen
    │   │   └── doctor/        ← DoctorHome, DoctorDashboard, Patients
    │   └── shared/
    │       └── theme/         ← AppTheme (light + dark)
    └── pubspec.yaml
```

---

## PART 1 — BACKEND SETUP

### Prerequisites
- Python 3.10 or higher
- A free **Groq API key** from https://console.groq.com
- Git

### Step 1 — Navigate to backend directory
```bash
cd OmniMind/backend
```

### Step 2 — Create virtual environment
```bash
python -m venv venv

# Activate on macOS/Linux:
source venv/bin/activate

# Activate on Windows:
venv\Scripts\activate
```

### Step 3 — Install dependencies
```bash
# Install original OmniMind dependencies first:
pip install -r requirements.txt

# Then install FastAPI API server dependencies:
pip install -r api_requirements.txt
```

### Step 4 — Set up environment variables
```bash
# Copy the example file:
cp .env.example .env

# Edit .env and add your Groq API key:
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GROQ_MODEL=llama-3.1-8b-instant
```

Get your free Groq API key at: https://console.groq.com/keys  
(The free tier allows ~6,000 requests/day — more than enough for development)

### Step 5 — Build the RAG knowledge base (one-time setup)
```bash
# Make sure you have PDF files in the data/ folder first
# The original setup.py handles this:
python setup.py
```

If `setup.py` doesn't exist yet, run:
```bash
python -c "from core.rag import RAGEngine; r = RAGEngine(); r.build(); print('RAG built!')"
```

### Step 6 — Start the API server
```bash
uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Application startup complete.
```

### Step 7 — Verify it's working
Open your browser and visit: http://localhost:8000/health

You should see:
```json
{"status": "ok", "model": "llama-3.1-8b-instant", "service": "OmniMind API"}
```

View the interactive API docs at: http://localhost:8000/docs

---

## PART 2 — FIREBASE SETUP

Firebase is used for authentication, chat history storage, and real-time patient data.

### Step 1 — Create a Firebase project
1. Go to https://console.firebase.google.com
2. Click **"Add project"** → Name it `OmniMind`
3. Disable Google Analytics (optional) → Click **"Create project"**

### Step 2 — Enable Authentication
1. In Firebase Console → **Authentication** → **Get started**
2. Click **Email/Password** → Toggle **Enable** → **Save**

### Step 3 — Enable Firestore
1. In Firebase Console → **Firestore Database** → **Create database**
2. Choose **"Start in test mode"** (for development)
3. Select your region → **Done**

### Step 4 — Add Android app to Firebase
1. In Firebase Console → **Project Overview** → Click **Android icon**
2. Android package name: `com.ibasuk.omnimind`
3. App nickname: `OmniMind`
4. Click **"Register app"**
5. **Download `google-services.json`**
6. Place it at: `flutter_app/omnimind/android/app/google-services.json`

### Step 5 — (Optional) Add iOS app to Firebase
1. Click **Add app** → iOS icon
2. Bundle ID: `com.ibasuk.omnimind`
3. Download `GoogleService-Info.plist`
4. Place it at: `flutter_app/omnimind/ios/Runner/GoogleService-Info.plist`

### Step 6 — Set Firestore Security Rules
In Firebase Console → Firestore → **Rules**, paste:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      match /messages/{msgId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /exercises/{exId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /diary/{entryId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /progress/{snapId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    match /doctors/{doctorId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == doctorId;
    }
  }
}
```
Click **Publish**.

---

## PART 3 — FLUTTER APP SETUP

### Prerequisites
- Flutter SDK 3.10.0 or higher
- Android Studio or VS Code with Flutter extension
- Android SDK (API level 21+)

### Step 1 — Install Flutter
Follow the official guide: https://docs.flutter.dev/get-started/install

Verify installation:
```bash
flutter doctor
```
Fix any issues shown by `flutter doctor` before proceeding.

### Step 2 — Navigate to Flutter project
```bash
cd OmniMind/flutter_app/omnimind
```

### Step 3 — Place `google-services.json`
Make sure `google-services.json` (downloaded in Firebase setup) is at:
```
flutter_app/omnimind/android/app/google-services.json
```

### Step 4 — Configure the backend URL

**For Android Emulator** (default — already set):
The emulator uses `10.0.2.2` to reach the host machine's localhost.
The default in `lib/core/services/api_service.dart` is already set to:
```dart
defaultValue: 'http://10.0.2.2:8000'
```

**For a Real Android Device** (on the same WiFi):
1. Find your computer's local IP address:
   - Windows: `ipconfig` → look for IPv4 Address
   - macOS/Linux: `ifconfig` or `ip addr` → look for inet address
2. Edit `lib/core/services/api_service.dart`, change:
   ```dart
   defaultValue: 'http://10.0.2.2:8000',
   ```
   to:
   ```dart
   defaultValue: 'http://YOUR_MACHINE_IP:8000',
   ```
   Example: `'http://192.168.1.105:8000'`

**For iOS Simulator**:
Use `http://localhost:8000` (simulator shares host network).

### Step 5 — Install Flutter dependencies
```bash
flutter pub get
```

### Step 6 — Add placeholder assets (required for first run)
```bash
# Create empty placeholder audio (the app gracefully handles missing audio)
mkdir -p assets/audio assets/images assets/lottie

# Create a simple placeholder icon (replace with your real icon later)
# On macOS/Linux:
echo "" > assets/images/placeholder.png
```

### Step 7 — Run on emulator

**Start an Android emulator** in Android Studio:
- Open Android Studio → **Device Manager** → **Create Virtual Device**
- Choose a Pixel device → API 33+ → **Finish** → **Play** button

Then run:
```bash
flutter run
```

Or run on a specific device:
```bash
flutter devices              # List available devices
flutter run -d emulator-5554 # Run on specific emulator
```

---

## PART 4 — RUNNING EVERYTHING TOGETHER

### Terminal 1 — Backend server
```bash
cd OmniMind/backend
source venv/bin/activate   # (or venv\Scripts\activate on Windows)
uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
```

### Terminal 2 — Flutter app
```bash
cd OmniMind/flutter_app/omnimind
flutter run
```

Both must be running simultaneously for the full experience.

---

## PART 5 — TESTING THE APP

### First-time user flow:
1. **App opens** → Splash screen (OmniMind logo)
2. **Sign Up** → Choose "Patient" or "Doctor" role
3. **Patient Dashboard** → See greeting, mood selector, quick actions
4. **Chat Tab** → Start talking to Dr. Mira (AI)
5. **After ~4 turns** → Exercise popup appears automatically
6. **Assessment Tab** → PHQ-9/GAD-7/PSS auto-filled from chat, or answer manually
7. **Diary Tab** → Write journal entries with mood emoji
8. **Exercises Tab** → Browse all CBT exercises

### Doctor flow:
1. **Sign Up** → Choose "Doctor" role
2. **Doctor Dashboard** → See patient count
3. **Patients Tab** → View assigned patients, add clinical notes

### Test messages to try in chat:
- "I've been feeling very anxious and can't sleep"
- "Everything feels hopeless lately"
- "I had a panic attack today"
- "I feel overwhelmed with work and family"
- "I'm having suicidal thoughts" (tests crisis detection)

---

## PART 6 — API ENDPOINTS REFERENCE

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server health check |
| POST | `/session/new` | Create a new chat session |
| POST | `/chat` | Send a message, get AI reply |
| GET | `/exercises` | List all CBT exercises |
| GET | `/exercise/{id}` | Get exercise details |
| POST | `/exercise/complete` | Mark exercise as done |
| GET | `/assess/status?session_id=X` | Get assessment scores |
| POST | `/assess/answer` | Submit a PHQ-9/GAD-7/PSS answer |
| GET | `/progress?session_id=X` | Get emotion history + progress |
| GET | `/session/export?session_id=X` | Export full session as JSON |

Interactive docs: http://localhost:8000/docs

---

## PART 7 — ENVIRONMENT VARIABLES

### Backend (`.env` file in `backend/` folder):
```
GROQ_API_KEY=gsk_your_key_here
GROQ_MODEL=llama-3.1-8b-instant
```

### Flutter (compile-time — optional):
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.105:8000
```

---

## PART 8 — TROUBLESHOOTING

### "Connection refused" in the app
- Make sure the backend server is running (`uvicorn api_server:app ...`)
- Check the API URL in `api_service.dart` matches your setup
- For physical devices: ensure your phone and computer are on the **same WiFi network**
- Try pinging from your phone browser: `http://YOUR_IP:8000/health`

### "GROQ_API_KEY not set" error
- Make sure you created the `.env` file in the `backend/` folder
- Make sure the key starts with `gsk_`
- Restart the uvicorn server after editing `.env`

### Firebase authentication errors
- Verify `google-services.json` is in `android/app/` (not the project root)
- Make sure Email/Password sign-in is enabled in Firebase Console
- Check that the package name in Firebase matches `com.ibasuk.omnimind`

### "RAG engine failed to load"
- Run `python setup.py` first to build the vector store
- Make sure PDF files exist in `backend/data/`
- The first load takes 2-5 minutes (model download)

### Flutter dependency errors
```bash
flutter clean
flutter pub get
flutter run
```

### Firestore permission denied
- Check your Firestore security rules (see Part 2, Step 6)
- Make sure you're signed in before reading/writing data

---

## PART 9 — PRODUCTION DEPLOYMENT

For a production deployment, replace these components:

| Component | Development | Production |
|-----------|-------------|------------|
| Backend hosting | Local `uvicorn` | AWS EC2 / Google Cloud Run / Railway |
| Backend URL | `10.0.2.2:8000` | `https://api.omnimind.app` |
| Firebase plan | Spark (free) | Blaze (pay-as-you-go) |
| LLM | Groq free tier | Groq paid / AWS Bedrock |
| SSL | None | Required (Let's Encrypt) |

---

## PART 10 — PROJECT CONTRIBUTORS

| Name | Role |
|------|------|
| Ibad Ur Rahman (133-22-0004) | Group Leader, Backend + AI |
| Shafique Ahmed (133-22-0006) | Mobile App Development |
| Khalid Hussain (133-22-0011) | UI/UX + Testing |
| Dr. Abdul Sattar Chan | Supervisor |
| Engr. Umair Ayaz Kamangar | Co-Supervisor |

**Institution**: Sukkur IBA University, Department of Computer Systems Engineering

---

*OmniMind — Democratizing mental health care through AI*
