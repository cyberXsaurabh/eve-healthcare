# Eve Healthcare – Diagnostic Booking Backend

A REST API backend for booking diagnostic tests at healthcare centres, with simulated payment processing.

Built with **FastAPI** + **PostgreSQL** + **SQLAlchemy**.

---

## Tech Stack

- **FastAPI** – API framework
- **PostgreSQL** – Database
- **SQLAlchemy** – ORM
- **Alembic** – Database migrations
- **python-jose** – JWT authentication
- **passlib + bcrypt** – Password hashing
- **Docker + docker-compose** – Containerisation
- **pytest** – Unit tests

---

## How to Run the Project

### Option 1: Using Docker (Recommended)

Make sure you have Docker and docker-compose installed.

```bash
# Clone the repo
git clone <your-repo-url>
cd eve-healthcare

# Start the app and database
docker-compose up --build
```

The API will be available at: **http://localhost:8000**

Swagger docs: **http://localhost:8000/docs**

---

### Option 2: Running Locally (without Docker)

**Prerequisites:**
- Python 3.11+
- PostgreSQL running locally

```bash
# 1. Create and activate a virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Mac/Linux

# 2. Install dependencies
pip install -r requirements.txt

# 3. Set up environment variables
copy .env.example .env
# Edit .env with your database URL and secret key

# 4. Run the application
uvicorn app.main:app --reload
```

The tables are created automatically on startup (via `Base.metadata.create_all`).

---

## Running Tests

Tests use SQLite in-memory, so no database setup is needed.

```bash
# Install dependencies first
pip install -r requirements.txt

# Run all tests
pytest

# With verbose output
pytest -v

# Run a specific test file
pytest tests/test_auth.py -v
```

---

## API Endpoints

### Health Check
| Method | URL | Description |
|--------|-----|-------------|
| GET | `/` | Health check |

### Authentication
| Method | URL | Auth Required | Description |
|--------|-----|---------------|-------------|
| POST | `/auth/signup` | No | Register a new user |
| POST | `/auth/login` | No | Login, get JWT token |

### Diagnostic Centres & Tests
| Method | URL | Auth Required | Description |
|--------|-----|---------------|-------------|
| GET | `/centres/` | No | List all centres (paginated) |
| POST | `/centres/` | No | Create a new centre |
| GET | `/centres/{id}` | No | Get a centre with its tests |
| GET | `/centres/{id}/tests` | No | List tests at a centre |
| POST | `/centres/{id}/tests` | No | Add a test to a centre |

### Bookings
| Method | URL | Auth Required | Description |
|--------|-----|---------------|-------------|
| POST | `/bookings/` | Yes | Create a booking |
| GET | `/bookings/` | Yes | List my bookings |
| GET | `/bookings/{id}` | Yes | Get a specific booking |
| PATCH | `/bookings/{id}/cancel` | Yes | Cancel a booking |

### Payments
| Method | URL | Auth Required | Description |
|--------|-----|---------------|-------------|
| POST | `/payments/` | Yes | Simulate a payment |
| POST | `/payments/webhook/` | No | Webhook for payment status updates |

---

## Example API Requests

### 1. Sign Up
```bash
curl -X POST http://localhost:8000/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"full_name": "Rahul Sharma", "email": "rahul@example.com", "password": "password123"}'
```

### 2. Login
```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "rahul@example.com", "password": "password123"}'
```
> Copy the `access_token` from the response.

### 3. Create a Diagnostic Centre
```bash
curl -X POST http://localhost:8000/centres/ \
  -H "Content-Type: application/json" \
  -d '{"name": "City Diagnostics", "location": "Mumbai"}'
```

### 4. Add a Test to the Centre
```bash
curl -X POST http://localhost:8000/centres/{centre_id}/tests \
  -H "Content-Type: application/json" \
  -d '{"name": "Complete Blood Count", "price": "450.00", "description": "Full blood panel"}'
```

### 5. Book a Test
```bash
curl -X POST http://localhost:8000/bookings/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your_token>" \
  -d '{"test_id": "<test_id>", "centre_id": "<centre_id>", "appointment_dt": "2026-12-01T10:00:00"}'
```

### 6. Make a Payment
```bash
curl -X POST http://localhost:8000/payments/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your_token>" \
  -d '{"booking_id": "<booking_id>"}'
```

### 7. Simulate Webhook
```bash
curl -X POST http://localhost:8000/payments/webhook/ \
  -H "Content-Type: application/json" \
  -d '{"event_id": "evt_abc123", "booking_id": "<booking_id>", "status": "SUCCESS"}'
```

---

## Database / Schema Design

### Tables

**users**
- `id` (UUID, PK)
- `full_name`, `email` (unique), `hashed_password`
- `is_active` (Boolean)
- `created_at` (Timestamp)

**diagnostic_centres**
- `id` (UUID, PK)
- `name`, `location`
- `created_at`

**diagnostic_tests**
- `id` (UUID, PK)
- `centre_id` (FK → diagnostic_centres)
- `name`, `price` (Numeric 10,2), `description`
- `created_at`

**bookings**
- `id` (UUID, PK)
- `user_id` (FK → users), `test_id` (FK → diagnostic_tests), `centre_id` (FK → diagnostic_centres)
- `appointment_dt` (Timestamp)
- `amount` (Numeric 10,2) — snapshot of price at booking time
- `status` (ENUM: PENDING / CONFIRMED / FAILED / CANCELLED)
- `created_at`

**payments**
- `id` (UUID, PK)
- `booking_id` (FK → bookings)
- `event_id` (String, UNIQUE) — used for idempotency
- `status` (ENUM: SUCCESS / FAILED)
- `created_at`

### Key Design Decisions

1. **Price snapshot**: The booking stores `amount` as a copy of the test price at the time of booking. This means if the test price changes later, old bookings still show the correct amount.

2. **Idempotent webhook**: The `event_id` column has a UNIQUE constraint. If the same webhook event is received more than once, we return the existing payment record without re-processing it.

3. **UUID primary keys**: Used across all tables for security (harder to guess than integer IDs) and to avoid exposing sequential IDs.

4. **Booking state machine**: A booking starts as PENDING. It moves to CONFIRMED or FAILED after payment. CANCELLED is only possible from PENDING.

---

## Important Assumptions

1. Creating diagnostic centres and tests is open to anyone (no admin role). In a real system, this would be restricted.

2. The simulated payment has a 70% success rate and 30% failure rate (random).

3. Appointment datetime is validated to be in the future at the time of booking.

4. The webhook endpoint is not authenticated (payment providers typically sign their webhooks — that could be added as an improvement).

5. I used `Base.metadata.create_all()` for table creation in development mode. In production, Alembic migrations would be the right approach.

---

## What I Would Improve With More Time

1. **Alembic migrations** – Proper migration scripts instead of `create_all()` on startup.

2. **Webhook signature verification** – In real life, payment providers sign webhook payloads (e.g., HMAC SHA256). We'd verify the signature before processing.

3. **Admin role** – Add an `is_admin` flag to users and restrict centre/test creation to admins only.

4. **Pagination metadata** – Return total count along with paginated results (e.g., `{"items": [...], "total": 50, "page": 1}`).

5. **Redis caching** – Cache the list of centres/tests since they don't change often.

6. **Celery + background tasks** – Process payments asynchronously instead of inline.

7. **Rate limiting** – Prevent abuse of the login and signup endpoints.

8. **Structured logging** – Use a proper logging library (like `structlog`) instead of `print()`.

9. **More tests** – Add integration tests that actually hit a test PostgreSQL database.

---

## Project Structure

```
eve_healthcare/
├── app/
│   ├── main.py               # App entry point
│   ├── config.py             # Settings from env vars
│   ├── database.py           # DB engine and session
│   ├── dependencies.py       # get_current_user dependency
│   ├── models/               # SQLAlchemy ORM models
│   ├── schemas/              # Pydantic request/response schemas
│   ├── routers/              # API route handlers
│   └── services/             # Business logic
├── tests/                    # Pytest test files
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── README.md
```
