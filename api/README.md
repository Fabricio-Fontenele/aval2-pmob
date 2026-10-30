# Campus Lost and Found API

Backend REST API for the Campus Lost and Found system, built with Dart, Shelf, and PostgreSQL.

## Features

- Built with pure Dart and Shelf (`shelf_router`).
- PostgreSQL client supporting TLS/SSL encryption for cloud providers (e.g. Supabase, Render, Neon).
- Graceful health checking with database status (`GET /health`).
- Error handling middleware and CORS support.
- Fully containerized with multi-stage Docker build for deployment on Render.

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
   cp .env.example .env
   ```

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
