Healthcare App

A full-stack healthcare management platform for medical practitioners — patient records, appointment scheduling, lab orders, pharmacy inventory, staff/ambulance dispatch, real-time doctor messaging, and an LLM-powered clinical medicine assistant.

Built as an end-to-end system: Flutter mobile client, FastAPI backend, PostgreSQL for persistence, Redis for caching/sessions/pub-sub, fully containerized with Docker.

# Features
1. Authentication — Phone + OTP verification, JWT sessions, Redis-backed OTP storage with TTL expiry
2. Patient Management — Multi-step patient intake, chief complaint tracking, severity triage
3. Appointments — Calendar-based scheduling, live dashboard stat integration, status workflow (scheduled/completed/cancelled/no-show)
4. Lab Management — Test ordering, status pipeline (pending → in progress → completed), result notes
5. Pharmacy — Shared medicine inventory, multi-item prescriptions, transaction-safe stock decrement with insufficient-stock rejection
6. Nurse Manager — Staff directory, patient assignment, duty-status tracking
7. Ambulance Dispatch — Fleet management with concurrency-safe auto-assignment (SELECT ... FOR UPDATE SKIP LOCKED), graceful handling of fleet exhaustion
8. Doctor Messaging — Real-time chat via WebSocket + Redis Pub/Sub, with per-conversation access control
9. AI Medicine Assistant — LLM-backed drug information lookup, scoped strictly to clinical queries, with mandatory disclaimer enforcement
10. Team Directory — Practice-wide doctor listing with privacy-gated contact info (phone revealed only after a conversation exists)
# Tech Stack
Layer	Technology
Mobile	Flutter, Provider (state management), Dio (HTTP), WebSocket
Backend	FastAPI, SQLAlchemy 2.0 (async), Pydantic, Alembic
Database	PostgreSQL 16
Cache / Sessions / Pub-Sub	Redis 7
AI	OpenAI API (clinical medicine assistant)
Infrastructure	Docker, Docker Compose
Architecture

Every backend module (Patients, Appointments, Lab, Pharmacy, Nurses, Ambulance, Messaging) enforces doctor-level data isolation — one practitioner can never read or write another's patient data. Cross-tenant access attempts return 404 (not 403) to avoid leaking record existence. This is verified with automated integration tests per module, not assumed from query structure.

mobile/          Flutter app — one feature folder per module,
                  mirroring the backend's module structure
backend/
  app/
    modules/      auth, patients, appointments, lab, pharmacy,
                  nurses, ambulance, messaging, dashboard, doctors
    ai_assistant/  LLM-backed medicine query endpoint
    core/          config, security, Redis client
    db/            SQLAlchemy session/engine setup
  alembic/         database migrations
  docker-compose.yml

# Key backend patterns used throughout:

Cache-aside for dashboard stats (Redis, 30s TTL), invalidated on every write that affects the cached data
Row-level locking (FOR UPDATE SKIP LOCKED) for ambulance auto-assignment to prevent race conditions under concurrent dispatch requests
WebSocket + Redis Pub/Sub bridge for real-time messaging across multiple connected clients
Getting Started
Prerequisites
Docker & Docker Compose
Flutter SDK
An OpenAI API key (for the AI Medicine Assistant)
Backend
bash
cd backend
cp .env.example .env   # fill in DATABASE_URL, REDIS_URL, JWT_SECRET, OPENAI_API_KEY
docker compose up --build -d
docker compose exec api alembic upgrade head

Verify it's running:

bash
curl http://localhost:8000/health
# {"status":"ok","db":true,"redis":true}

API docs available at http://localhost:8000/docs.

Mobile
bash
cd mobile
flutter pub get

Update lib/core/constants.dart with your backend's LAN IP if testing on a physical device:

dart
static const String baseUrl = 'http://<your-lan-ip>:8000';
bash
flutter run
Security Notes
JWT-based auth with Redis-backed OTP (single-use, 5-minute expiry)
Doctor-scoped data access enforced at the query level across every module, not just the UI
WebSocket connections validate conversation participation before allowing a connection
Contact information (phone numbers) gated behind an existing relationship (conversation), not exposed in the general directory
