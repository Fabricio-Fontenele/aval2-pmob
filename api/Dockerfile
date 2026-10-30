# Multi-stage Dockerfile for Campus Lost and Found API
# Stage 1: Build AOT executable
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Minimal runtime image
FROM debian:bookworm-slim

# Install ca-certificates for secure HTTPS and TLS connections to cloud PostgreSQL (e.g. Supabase)
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/bin/server /app/bin/server

# Render uses the PORT environment variable
ENV PORT=8080
ENV HOST=0.0.0.0
ENV ENVIRONMENT=production

EXPOSE 8080

CMD ["/app/bin/server"]
