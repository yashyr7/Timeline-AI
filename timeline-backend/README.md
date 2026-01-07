# Timeline Backend

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

## Notes

- Add your firebase service account keys (timeline-backend/firebase-service-account.json) to the backend repository to run the app successfully.
