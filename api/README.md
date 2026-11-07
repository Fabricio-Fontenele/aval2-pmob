# Campus Lost and Found API

Backend REST API for the Campus Lost and Found system, built with Dart, Shelf, and PostgreSQL.

## Features

- Built with pure Dart and Shelf (`shelf_router`).
- PostgreSQL client supporting TLS/SSL encryption for cloud providers (e.g. Supabase, Render, Neon).
- Graceful health checking with database status (`GET /health`).
- Error handling middleware and CORS support.
- Fully containerized with multi-stage Docker build for deployment on Render.
- Server-side session issuance, validation, expiration, and revocation backed by
  PostgreSQL; authorization middleware and session/logout HTTP endpoints.
- Account registration and login with Argon2id password hashing, atomic account
  and session creation, generic credential errors, and configurable attempt limits.

See [authentication contracts and progress](../docs/authentication.md) for the
implemented authentication routes, integration tests, and current limitations.

## Live Deployment

The API is deployed on **Render** backed by **Supabase PostgreSQL**:
- **Base URL:** `https://campus-lost-found-api-zv3r.onrender.com`
- **Health Check:** `https://campus-lost-found-api-zv3r.onrender.com/health`
- **Items Endpoint:** `https://campus-lost-found-api-zv3r.onrender.com/items`
- **Database:** Supabase PostgreSQL with TLS/SSL encryption enabled.

## Getting Started

### Prerequisites

- Dart SDK (>= 3.0.0)
- (Optional) Docker and Docker Compose for local database testing

### Running Locally

1. Install dependencies:
   ```bash
   dart pub get
   ```

2. Start a local PostgreSQL instance (optional, using Docker Compose):
   ```bash
   docker compose up -d postgres
   ```

3. Set up environment variables:
   ```bash
   export DATABASE_URL='<connection string for your own PostgreSQL>'
   export SESSION_TTL_HOURS=24
   ```

   In PowerShell, use `$env:DATABASE_URL = '<connection string for your own PostgreSQL>'`
   and `$env:SESSION_TTL_HOURS = '24'`. `.env.example` lists the available
   parameters; the API reads process environment variables and does not load
   `.env` files automatically. A nonpositive session lifetime is rejected.

4. Run the API:
   ```bash
   dart run bin/server.dart
   ```

5. Test the health endpoint:
   ```bash
   curl http://localhost:8080/health
   ```

### Running Tests

Execute the automated test suite:
```bash
dart test
```

Run static analysis:
```bash
dart analyze
```

The real PostgreSQL integration tests run when `TEST_DATABASE_URL` is set in the
process environment. Use an isolated test database with schema creation
privileges, as described in the [authentication guide](../docs/authentication.md#verification-and-handoff).
They skip explicitly when that configuration is absent.

## Authentication

`POST /auth/register` and `POST /auth/login` accept JSON containing only `email`
and `password`. Registration returns `201`; login returns `200`. Both return
the public user ID, an opaque token, and UTC expiration. Account creation also
creates the first session atomically. Password confirmation remains on the
client, and no email-confirmation service is required for demonstration accounts.

Use a demonstration address under `example.test` and a unique password with at
least eight Unicode code points. Keep the original password, including spaces,
and transmit the token only through the Bearer header over HTTPS after deployment.
`GET /auth/session` restores a valid session; `POST /auth/logout` revokes it.

`.env.example` includes attempt limits, maximum active authentication operations,
and the trusted proxy allowlist. The default limiter belongs to one API process;
counters reset on restart. Hosting configuration must verify the trusted proxy
addresses before using forwarded client-address headers. See the guide for
response codes, precise rules, and deployment parameters.

### Deployment to Render

1. Create a new **Web Service** on [Render](https://render.com).
2. Connect your GitHub repository.
3. Configure the service:
   - **Environment:** Docker
   - **Root Directory:** `api`
   - **Dockerfile Path:** `Dockerfile`
4. In **Environment Variables**, add:
   - `PORT`: `8080` (or Render's default `$PORT`)
   - `ENVIRONMENT`: `production`
   - `DATABASE_URL`: Connection string provided by your PostgreSQL instance (e.g., Supabase transaction pooler URL with `?sslmode=require`).
