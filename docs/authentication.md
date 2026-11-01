# Authentication contracts and implementation progress

This document records Fabricio's implementation increments for P01, P02, and P03
in the [development plan](development_plan.md). Authentication is additional
requested scope; the [official assignment](pmob-aval2.pdf) does not require it.

## Current scope and dependencies

| Package | Current evidence | Remaining work |
| --- | --- | --- |
| P01 | Initial HTTP contracts below; Argon2id library selected and benchmarked locally | Francisco's review and benchmark on the free hosting environment from P05 |
| P02 | API validation, registration/login services and routes, atomic account/session SQL, duplicate-email handling, and attempt/concurrency limits implemented and tested locally | Run the real PostgreSQL integration test and deployment checks; P13 must match the API's validation contract |
| P03 | Session issuance, validation, expiration, revocation, PostgreSQL adapter, authorization middleware, and session/logout routes implemented | Run the PostgreSQL integration test; verify persistence across actual API restarts and HTTPS deployment; connect authorization to P07 |
| P04 | Authentication HTTP endpoints available for the adapter | Flutter foundation from P09, secure token storage, and adapter tests |

The API foundation already existed when this increment started. Its health
endpoint and schema do not establish completion of P05/P06: cloud connectivity,
private table permissions, database constraints, and free hosting viability
still need their planned evidence. The Flutter scaffold and P13 validators are
also absent. These dependencies affect completion, while independent session
and cryptographic code can be tested now.

Registration and login are now available in the API. Local implementation does
not establish cloud acceptance: database permissions, real PostgreSQL checks,
HTTPS deployment, and the mobile client still require their planned evidence.

## HTTP contracts

Use HTTPS outside local development. Send JSON with UTF-8 encoding. Identifiers
and error codes are English; messages shown to users are Brazilian Portuguese.
Dates use UTC ISO 8601 strings. The client never sends a user identifier to select
the account that owns a session or a new object.

| Endpoint | Success | Authentication | Implementation |
| --- | --- | --- | --- |
| `POST /auth/register` | `201` with issued-session response | Public; subject to registration limits | Available |
| `POST /auth/login` | `200` with issued-session response | Public; subject to login limits | Available |
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

Email validation accepts practical ASCII mailbox addresses, including plus
aliases, and requires a dotted domain with valid labels. It rejects leading,
trailing, and consecutive dots in the local part. P13 must preserve the same
accepted inputs and count password length using Unicode code points, rather
than UTF-16 code units or visible grapheme clusters.

Requests require `Content-Type: application/json` and valid UTF-8. The API limits
the body to 8 KiB and its total read time to ten seconds. Unexpected fields,
including client-supplied identity and password confirmation, are rejected.

An issued-session response has this structure:

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
registration and login also include it.

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
| `400` | `invalid_request` | Invalid JSON, unexpected fields, or invalid inputs; field errors under `error.fields`, keyed by `email` or `password` | Implemented |
| `408` | `invalid_request` | Reading the body exceeded ten seconds; retry explicitly | Implemented |
| `413` | `invalid_request` | Body exceeded 8 KiB; reduce the submitted payload | Implemented |
| `415` | `invalid_request` | Content type is not JSON | Implemented |
| `401` | `invalid_credentials` | Generic login rejection; do not distinguish an unknown email from a wrong password | Implemented |
| `401` | `invalid_session` | Missing, malformed, unknown, expired, or revoked token; end authenticated presentation state and request sign-in for protected actions | Implemented |
| `409` | `email_in_use` | Normalized email already registered, including concurrent insertions | Implemented |
| `429` | `too_many_attempts` | Attempt limit exceeded; includes `Retry-After` in seconds | Implemented |
| `503` | `service_unavailable` | Storage unavailable, service unconfigured, or concurrency capacity exhausted; preserve local session data and allow explicit retry | Implemented |

Implemented `401` responses include `WWW-Authenticate: Bearer`. Expiration or
revocation is not inferred from a network failure or a `503` response.

Logout succeeds only after storage confirms revocation. If storage fails, it
returns `503` and allows retry. An already inactive session returns `401`,
including when a logout succeeded remotely but its response was lost; this is
definitive rejection of that token, so the client clears its authenticated state.
Do not automatically repeat object writes after session recovery.

## Attempt limits and deployment parameters

The implemented defaults allow five registration attempts per source address
per hour, and five login attempts per normalized email plus twenty per source
address in fifteen minutes. Every request consumes the address budget before
body decoding and hashing; validated login input also consumes the email budget.
Successful requests count as attempts. Denials preserve the original window
expiration and include rounded-up `Retry-After` seconds.

| Environment parameter | Default | Purpose |
| --- | --- | --- |
| `AUTH_REGISTER_LIMIT` | `5` | Registration attempts per source address/hour |
| `AUTH_LOGIN_EMAIL_LIMIT` | `5` | Login attempts per normalized email/15 minutes |
| `AUTH_LOGIN_ADDRESS_LIMIT` | `20` | Login attempts per source address/15 minutes |
| `AUTH_MAX_CONCURRENT` | `2` | Maximum active registration/login operations per service |
| `TRUSTED_PROXY_IPS` | Empty | Comma-separated exact IP addresses of trusted proxies |

Numeric limits must be positive. Counters have a bounded capacity of 10,000
entries; full capacity rejects new keys until an entry expires, preserving
existing active limits. Counters belong to one API process and reset on restart.
Use one API instance for these documented limits. Multiple instances require
shared counter storage before deployment at that scale.

The service admits at most `AUTH_MAX_CONCURRENT` operations before hashing and
database work. Excess operations receive `503` with `Retry-After: 1`; there is no
unbounded work queue. Unknown accounts still perform Argon2id verification, and
known/unknown invalid credentials produce the same public error.

Source addresses come from Shelf's socket connection metadata. Forwarded
headers are ignored unless the immediate peer is explicitly trusted. For trusted
peers, the API walks `X-Forwarded-For` right to left through the configured proxy
chain and stops at the first untrusted address. Malformed chains fall back to
the immediate peer. Configure only proxies that append the actual connecting
address. With an empty allowlist behind a reverse proxy, users share that proxy's
address budget. Francisco must verify the actual hosting topology and these
thresholds during P05/P08; no proxy address has been assumed for the provider.

## Implementation boundaries

- `auth/domain/` contains immutable session data, persistence contracts, and
  exceptions, without Shelf, PostgreSQL, or Flutter imports.
- `SessionService` issues tokens, computes their hash, and checks session
  lifetime/revocation. Its clock is injectable for exact expiration tests.
- `AuthCredentials` owns reusable email/password validation in pure Dart.
- `AuthService` hashes registration passwords, checks login credentials, bounds
  active operations, and returns sessions only after confirmed persistence.
- `PostgresAccountStore` creates the user and first session atomically and
  retrieves only the stored credentials needed for login.
- `PostgresSessionStore` uses parameterized SQL against the existing `sessions`
  table. It maps driver, I/O, and timeout failures to a safe storage exception.
  Revocation uses one conditional update, so only an active session is changed.
- `session_http.dart` owns header parsing, session responses, and
  `requireSession`. The middleware supplies an `AuthSession` in request context
  under `authenticatedSessionKey`; P07 derives `created_by` from its `userId`.
- `buildServerHandler` assembles the PostgreSQL store and session service when a
  database client exists. The existing server entry point uses that assembly;
  no in-memory fallback is configured for production sessions.

Registration uses one parameterized SQL statement containing a data-modifying
CTE. The statement inserts the normalized email and Argon2id hash, then inserts
the first session using the returned user ID. PostgreSQL executes the statement
atomically: a session failure rolls back the account insertion. The existing
`users.email` unique constraint arbitrates concurrent normalized-email inserts;
`ON CONFLICT (email) DO NOTHING` produces the documented `409` without an extra
session. See PostgreSQL's [data-modifying CTE documentation](https://www.postgresql.org/docs/current/queries-with.html#QUERIES-WITH-MODIFYING).
This removes the previously proposed need for an additional transaction API in
`DatabaseClient`. The token is prepared before the statement and returned only
after its successful completion. No schema change or new dependency was needed.

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

The PostgreSQL integration tests require `TEST_DATABASE_URL` in the process
environment and skip explicitly when absent:

```sh
dart test test/auth/data/postgres_session_store_integration_test.dart
dart test test/auth/data/postgres_account_store_integration_test.dart
```

Use a separate PostgreSQL test database. The session integration test creates a
connection-local temporary `sessions` table and closes its connection on completion, leaving
application tables untouched. It checks the real SQL adapter, expiration data,
hashed storage, and conditional revocation. Reconstructing a service over the
same connection does not prove persistence across an actual database/API restart
or public-table access restrictions; those remain deployment acceptance checks.

The account integration test needs schema creation privileges on that isolated
test database. It creates a randomly named `p02_auth_...` schema, runs the actual
project migration, and opens two independent connections to test competing
registrations. It also forces a session uniqueness failure and checks that the
new user was rolled back. Cleanup drops only that test schema and closes both
connections. Never point `TEST_DATABASE_URL` at the evaluation database.

Local verification on October 31, 2026:

- `dart pub get`: completed.
- `dart format` on the 15 affected Dart files: completed; unrelated files kept outside the formatting scope.
- `dart analyze`: no issues.
- `dart test`: 36 passed; one PostgreSQL integration test explicitly skipped because `TEST_DATABASE_URL` is absent.
- AOT compilation of `bin/server.dart` and the benchmark: completed; outputs remain ignored under `api/build/`.
- Compiled API startup on `127.0.0.1:18089`: confirmed. At that checkpoint, HTTP checks returned `200` for health, `401` for session/logout without a token, `503` for session validation with no database configured, and `404` for the then-unimplemented registration route.

Local P02 verification on November 1, 2026:

- Domain validation covers blank/mistyped fields, normalized email, unchanged passwords, and exact seven/eight-code-point boundaries.
- Service tests cover registration, duplicate accounts, login, unknown/wrong credentials, corrupt stored hashes, persistence failures, retries, and bounded pending operations.
- HTTP tests cover the issued-session contract, field errors, rejected client identity/confirmation, concurrent duplicates, safe failures, attempt limits, busy responses, and request parsing/size/time failures.
- `dart analyze --fatal-infos`: no issues.
- `dart test`: 98 passed; two PostgreSQL integration tests skipped because `TEST_DATABASE_URL` is absent.
- `dart compile exe bin/server.dart -o build/lost_and_found_api.exe`: completed.
- Compiled startup on `127.0.0.1:18089` confirmed; real HTTP requests exercised `200` health, `400` invalid fields/JSON, `503` unavailable storage, `429` attempt limits, and `401` missing session. The temporary server was stopped afterward.

The API implementation uses the real PostgreSQL adapters. Successful account
and login HTTP flows were verified with test-only storage; no successful remote
registration, database rollback/concurrency run, or HTTPS check is claimed here.

The first regression test failed with `404` instead of `401` before the session
routes were implemented. Local database credentials, Docker/PostgreSQL tooling,
and cloud deployment are unavailable in this workspace. Do not mark A13, A14,
A15, A17, or A18 as fully accepted based on isolated tests: account flows, mobile lifecycle,
real database transaction verification, deployment, and secure device storage remain pending.

Next, run the integration tests with Francisco's P06 database setup and verify
the deployed routes in P08. Willamy's P13 validation must follow the implemented
rules above. P04 can consume the available HTTP endpoints once P09 supplies the
Flutter package. Francisco can connect `requireSession` to `POST /items` while
keeping object reads public. No remote push or hosting deployment is performed
as part of this local P02 implementation.
