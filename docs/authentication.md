# Authentication contracts and implementation progress

This document records Fabricio's first implementation increment for P01 and P03
in the [development plan](development_plan.md). Authentication is additional
requested scope; the [official assignment](pmob-aval2.pdf) does not require it.

## Current scope and dependencies

| Package | Current evidence | Remaining work |
| --- | --- | --- |
| P01 | Initial HTTP contracts below; Argon2id library selected and benchmarked locally | Francisco's review and benchmark on the free hosting environment from P05 |
| P02 | Password hashing and session issuance are available as building blocks | Account validation, registration, login, transactional account/session creation, concurrent email uniqueness, and attempt limits |
| P03 | Session issuance, validation, expiration, revocation, PostgreSQL adapter, authorization middleware, and session/logout routes implemented | Run the PostgreSQL integration test; verify persistence across actual API restarts and HTTPS deployment; connect authorization to P07 |
| P04 | HTTP contracts ready for the adapter | Flutter foundation from P09, P02 endpoints, secure token storage, and adapter tests |

The API foundation already existed when this increment started. Its health
endpoint and schema do not establish completion of P05/P06: cloud connectivity,
private table permissions, database constraints, and free hosting viability
still need their planned evidence. The Flutter scaffold and P13 validators are
also absent. These dependencies affect completion, while independent session
and cryptographic code can be tested now.

No work package is marked complete solely by this increment. No account creation
or login route is exposed yet, and there is no public token-issuance endpoint.

## HTTP contracts

Use HTTPS outside local development. Send JSON with UTF-8 encoding. Identifiers
and error codes are English; messages shown to users are Brazilian Portuguese.
Dates use UTC ISO 8601 strings. The client never sends a user identifier to select
the account that owns a session or a new object.

| Endpoint | Success | Authentication | Implementation |
| --- | --- | --- | --- |
| `POST /auth/register` | `201` with issued-session response | Public; subject to registration limits | Planned in P02 |
| `POST /auth/login` | `200` with issued-session response | Public; subject to login limits | Planned in P02 |
| `GET /auth/session` | `200` with public identity and expiration | Bearer token | Available |
| `POST /auth/logout` | `204`, empty body | Bearer token | Available |

Registration and login receive exactly `email` and `password`. Password
confirmation is local and is never transmitted or persisted. Normalize email
with `trim().toLowerCase()` before validation, lookup, and insertion; enforce
uniqueness atomically in PostgreSQL. Reject absent/blank fields and invalid email.
The registration password must contain at least eight Unicode code points and
must not be whitespace-only. Preserve its original bytes, including leading and
trailing spaces; hashing uses UTF-8. P13 must implement matching client validation.
Login verifies the original password, without applying registration rules to
alter its contents.

An issued-session response, planned for P02, has this structure:

```json
{
  "user": { "id": "<user UUID>" },
  "token": "<opaque session token>",
  "expiresAt": "2026-11-01T12:00:00.000Z"
}
```

`GET /auth/session` returns only `user` and `expiresAt` from that structure. It
does not return the token, email, password hash, token hash, or account metadata.
Session and logout responses include `Cache-Control: no-store`. Successful
registration and login must also include it when P02 is implemented.

Send the token only through `Authorization: Bearer <token>`. The implemented
middleware accepts a case-insensitive Bearer scheme and a single 43-character,
unpadded Base64URL token. Query parameters, cookies, and request bodies cannot
substitute for the header.

Authentication errors use this envelope:

```json
{
  "error": {
    "code": "invalid_session",
    "message": "Sessão inválida ou expirada. Entre novamente."
  }
}
```

| Status | Code | Meaning and client behavior | Availability |
| --- | --- | --- | --- |
| `400` | `invalid_request` | Invalid JSON, unexpected fields, or invalid inputs; planned field errors under `error.fields`, keyed by `email` or `password` | P02 contract |
| `401` | `invalid_credentials` | Generic login rejection; do not distinguish an unknown email from a wrong password | P02 contract |
| `401` | `invalid_session` | Missing, malformed, unknown, expired, or revoked token; end authenticated presentation state and request sign-in for protected actions | Implemented |
| `409` | `email_in_use` | Normalized email already registered, including concurrent insertions | P02 contract |
| `429` | `too_many_attempts` | Attempt limit exceeded; include `Retry-After` in seconds | P02 contract |
| `503` | `service_unavailable` | Storage unavailable or service unconfigured; preserve local session data and allow explicit retry | Implemented for session operations |

Implemented `401` responses include `WWW-Authenticate: Bearer`. Expiration or
revocation is not inferred from a network failure or a `503` response.

Logout succeeds only after storage confirms revocation. If storage fails, it
returns `503` and allows retry. An already inactive session returns `401`,
including when a logout succeeded remotely but its response was lost; this is
definitive rejection of that token, so the client clears its authenticated state.
Do not automatically repeat object writes after session recovery.

P02's initial attempt-limit proposal is five registration attempts per source
address per hour, and five login attempts per normalized email plus twenty per
source address in fifteen minutes. Review these values with Francisco before
exposing P02. Enforcement must precede expensive hashing, use trusted proxy
configuration for source addresses, and bound concurrent hash operations. These
limits and their configuration are **not implemented** in this increment.

## Implementation boundaries

- `auth/domain/` contains immutable session data, persistence contracts, and
  exceptions, without Shelf, PostgreSQL, or Flutter imports.
- `SessionService` issues tokens, computes their hash, and checks session
  lifetime/revocation. Its clock is injectable for exact expiration tests.
- `PostgresSessionStore` uses parameterized SQL against the existing `sessions`
  table. It maps driver, I/O, and timeout failures to a safe storage exception.
  Revocation uses one conditional update, so only an active session is changed.
- `session_http.dart` owns header parsing, session responses, and
  `requireSession`. The middleware supplies an `AuthSession` in request context
  under `authenticatedSessionKey`; P07 derives `created_by` from its `userId`.
- `buildServerHandler` assembles the PostgreSQL store and session service when a
  database client exists. The existing server entry point uses that assembly;
  no in-memory fallback is configured for production sessions.

For P02, registration must create the user and session in **one database
transaction** and return success only after commit. `SessionService.issue` alone
is not an account-registration transaction. Bind its `SessionStore` to the same
transaction that inserts the user; do not create the user and then issue the
session through separate committed operations. The database foundation currently
needs a transaction boundary for that implementation.

Use `SESSION_TTL_HOURS` from the existing process environment configuration. The
default is 24 hours; the service rejects a nonpositive lifetime. There is no
refresh token, automatic renewal, Supabase Auth, or device password persistence.
The database owns session durability; API process restarts must not issue
replacement sessions simply to restore a token.

## Cryptographic choice and local evidence

The API adds [`hashlib` 2.4.2](https://pub.dev/packages/hashlib), a pure Dart library
with Argon2id, PHC serialization, and SHA-256. Password hashing uses Argon2id v19,
19,456 KiB memory, two iterations, one lane, a fresh 16-byte secure salt, and a
32-byte digest. This matches the 19 MiB/two-iteration profile in the
[OWASP password storage guidance](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).
PHC strings preserve salt and parameters in `password_hash`. Verification uses
the library's constant-time digest comparison. Hashing and verification run in
an isolate to keep the HTTP event loop available.

Tokens use 32 bytes from Dart's `Random.secure()`, encoded as unpadded Base64URL.
Only their SHA-256 hex digests are stored in `sessions.token_hash`. The original
token is returned to the caller at issuance and is never included in session
lookup responses. This implements the opaque-token approach in the plan and the
[OWASP session guidance](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html).

The reproducible benchmark prints only timing, parameters, and process memory:

```sh
dart run tool/benchmark_password_hash.dart
dart compile exe tool/benchmark_password_hash.dart -o build/password_hash_benchmark.exe
```

Run from `api/`; the compiled filename above is for Windows. On the local Windows
machine with Dart 3.13.5, three warmed AOT runs measured 38–39 ms to hash and
38–40 ms to verify, including isolate overhead. Peak process RSS was about
51.5 MiB. These are local observations, not hosting guarantees. P01 still needs
the same measurement on P05's free hosting configuration, including concurrent
requests. Build outputs stay under ignored `api/build/`.

## Verification and handoff

Run the API checks from `api/`:

```sh
dart pub get
dart analyze
dart test
dart compile exe bin/server.dart -o build/lost_and_found_api.exe
```

The focused tests cover issuance, unique tokens, hashed persistence boundaries,
service reconstruction, exact expiration, independent session revocation,
failed operations and retry, HTTP status/body/headers, middleware authorization,
password verification, and translation of PostgreSQL/network/timeout failures.
In-memory session storage lives only under `test/support/`.

The PostgreSQL integration test requires `TEST_DATABASE_URL` in the process
environment and skips explicitly when absent:

```sh
dart test test/auth/data/postgres_session_store_integration_test.dart
```

Use a separate PostgreSQL test database. This test creates a connection-local
temporary `sessions` table and closes its connection on completion, leaving
application tables untouched. It checks the real SQL adapter, expiration data,
hashed storage, and conditional revocation. Reconstructing a service over the
same connection does not prove persistence across an actual database/API restart
or public-table access restrictions; those remain deployment acceptance checks.

Local verification on October 31, 2026:

- `dart pub get`: completed.
- `dart format` on the 15 affected Dart files: completed; unrelated files kept outside the formatting scope.
- `dart analyze`: no issues.
- `dart test`: 36 passed; one PostgreSQL integration test explicitly skipped because `TEST_DATABASE_URL` is absent.
- AOT compilation of `bin/server.dart` and the benchmark: completed; outputs remain ignored under `api/build/`.
- Compiled API startup on `127.0.0.1:18089`: confirmed. HTTP checks returned `200` for health, `401` for session/logout without a token, and `503` for session validation with no database configured. Registration still returns `404`, as documented for this increment.

The first regression test failed with `404` instead of `401` before the session
routes were implemented. Local database credentials, Docker/PostgreSQL tooling,
and cloud deployment are unavailable in this workspace. Do not mark A13, A14,
A15, A17, or A18 as fully accepted based on isolated tests: account flows, mobile lifecycle,
transactional registration, deployment, and secure device storage remain pending.

Next, implement P02 after agreeing the account-validation contract with P13 and
the database transaction/uniqueness contract with P06. P04 can then use these
HTTP responses once P09 supplies the Flutter package. Francisco can connect
`requireSession` to `POST /items` while keeping object reads public.
