### LANDA – Local AI Network for Disaster Alerts

BorNEO HackWknd 2026 | Case Study 5: Disaster Resilience AI

**Team:** [Team Name]
**Track:** Technical Track B
**SDG Targets:** SDG 11.5 + SDG 13

---

### 🔗 Project Links

- 🎥 Demo Video (YouTube Unlisted): [PASTE YOUTUBE LINK HERE]
- 🖼️ Figma Prototype: [PASTE FIGMA LINK HERE]
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

- ChatGPT: used for report drafting, debugging, research
- GitHub Copilot: code scaffolding for Flutter and FastAPI
- Midjourney/DALL-E: UI concept image generation
- Perplexity AI: literature review and case study research

---

### 🌏 SDG Alignment

- SDG 11: Sustainable Cities and Communities (Target 11.5)
- SDG 13: Climate Action
