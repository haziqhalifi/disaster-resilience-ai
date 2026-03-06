# Disaster Resilience AI

A monorepo for a disaster resilience platform combining a Flutter mobile app, a FastAPI backend, and Python-based AI/ML models.

## Repository Structure

```
disaster-resilience-ai/
├── frontend_flutter/    # Flutter mobile application
├── backend_fastapi/     # FastAPI REST API server
└── ai_models/           # Python package for ML models
```

## Components

### 1. Frontend — Flutter Mobile App (`frontend_flutter/`)

A cross-platform mobile application built with Flutter that communicates with the FastAPI backend to display disaster alerts and risk predictions.

### 2. Backend — FastAPI REST API (`backend_fastapi/`)

A Python REST API that serves disaster alert data and exposes ML model predictions via HTTP endpoints.

### 3. AI Models — Python ML Package (`ai_models/`)

A Python package containing machine learning models for disaster risk prediction. Imported by the backend as a local package.

---

## Getting Started

### Prerequisites

- Python 3.10+
- Flutter SDK 3.x+
- pip / virtualenv

### Running the Backend

```bash
cd backend_fastapi

# Create and activate a virtual environment
python -m venv venv
# Windows
venv\Scripts\activate
# macOS/Linux
venv\Scripts\activate

# Install dependencies (includes ai_models as editable local package)
pip install -r requirements.txt
pip install -e ../ai_models

# Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

### Running the Flutter App

```bash
cd frontend_flutter/disaster_resilience_ai

# Get dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

Update the backend base URL in `lib/services/api_service.dart` if your server is not at `http://10.0.2.2:8000` (Android emulator default for localhost).

---

## License

MIT
