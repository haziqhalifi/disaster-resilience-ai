### LANDA – Local AI Network for Disaster Alerts

BorNEO HackWknd 2026 | Case Study 5: Disaster Resilience AI

**Team:** Lailatul Coder
**Track:** Technical Track B
**SDG Targets:** SDG 11.5 + SDG 13

---

### 🔗 Project Links

- 🎥 Demo Video (YouTube Unlisted): https://youtu.be/GB5vSpPMGHQ
- 📄 Final Report: /docs/Final-Report.pdf

---

### 📱 About LANDA

LANDA is an AI-powered disaster resilience platform built for rural ASEAN communities, combining hyper-local alerts, AI-assisted risk mapping, community reporting, IoT siren fallback, school preparedness tools, and multilingual delivery so vulnerable populations can receive, understand, and act on critical disaster information even when connectivity is limited.

---

### 🚀 Setup Instructions

#### Frontend (Flutter)

The Flutter client is located in `frontend_flutter/disaster_resilience_ai`.

```bash
cd frontend_flutter/disaster_resilience_ai
flutter pub get
flutter run
```

#### Backend (FastAPI)

```bash
cd backend_fastapi
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

#### AI Models

```bash
cd ai_models
pip install -r requirements.txt
python services/inference.py
```

---

### 🗂️ Repository Structure

```text
landa-disaster-resilience-ai/
|-- README.md
|-- admin_website/
|   |-- index.html
|   |-- login.html
|   `-- js/
|-- ai_models/
|   |-- __init__.py
|   |-- pyproject.toml
|   |-- requirements.txt
|   |-- models/
|   `-- services/
|-- backend_fastapi/
|   |-- requirements.txt
|   |-- app/
|   |   |-- api/
|   |   |-- core/
|   |   |-- db/
|   |   |-- schemas/
|   |   `-- services/
|   |-- migrations/
|   |-- scripts/
|   `-- uploads/
|-- docs/
|   |-- Demo-Video.md
|   |-- Final-Report.pdf
|   |-- malaysia.district.geojson
|   |-- Selangor_DUN_2015.geojson
|   `-- supabase_migrations.sql
`-- frontend_flutter/
    `-- disaster_resilience_ai/
        |-- android/
        |-- assets/
        |-- ios/
        |-- lib/
        |-- pubspec.yaml
        |-- web/
        `-- windows/
```

---

### 🤖 AI Acknowledgement

| Tool | Usage | % Contribution |
|------|--------|----------------|
| **Claude** | Code structuring (Flutter/FastAPI/ML), debugging, live multi-agent validation feature | 50% |
| **Google Gemini** | Early research, logo/visual assets | 15% |
| **Kiro AI** | Requirements gathering & specs | 10% |
| **Cursor/Antigravity** | AI code editors (navigation/suggestions) | 15% |
| **Perplexity AI** | Research, report drafting/references | 10% |

**Note:** All final code, architecture decisions, and core implementation done by team members. Claude powers our live report validation feature via Anthropic API.

---

### 🌏 SDG Alignment

- SDG 11: Sustainable Cities and Communities (Target 11.5)
- SDG 13: Climate Action
