# Timeline AI

Monorepo with two main projects: a Python backend that integrates with Firebase, and a Flutter frontend app.

## Timeline Backend

## What it does

- A Python service that interacts with Firebase (auth, Firestore, tasks/workflows) to schedule workflows at user's defined schedule using Celery and RabbitMQ.

## How to run

```bash
cd timeline-backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# Make sure environment variables and credentials are available (see .env)
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/firebase-service-account.json"
python src/main.py
```

## Timeline Flutter

## What it does

- A cross-platform Flutter application (Android/iOS/web/desktop) that provides the Timeline UI and talks to the backend/Firebase.

## How to run

```bash
cd timeline-flutter
flutter pub get
flutter run
```

## Repo layout (top-level)

- `timeline-backend/` — Python backend with Firebase integration.
- `timeline-flutter/` — Flutter frontend app.

## Notes

- Add your firebase service account keys (timeline-backend/firebase-service-account.json) to the backend repository and firebase config (timeline-flutter/lib/firebase_options.dart) to run the app successfully.
