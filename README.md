# Campus Lost and Found

Academic project for the second assessment of the Mobile Programming course at
Universidade Estadual do Piauí (UESPI). The planned application uses Flutter and
Dart to publish and browse lost and found objects in the university community.

Public repository: [Fabricio-Fontenele/aval2-pmob](https://github.com/Fabricio-Fontenele/aval2-pmob).

## Project status

The repository contains the assignment, development plan, agent instructions,
and repository configuration. The custom Dart HTTP API in `api/` implements
database schema migrations, account registration, login, Argon2id password
hashing, server-side sessions, authorization middleware, attempt limits, and
item listing and publication endpoints, with automated tests and Docker support.

The Flutter application includes the Material 3 shell with Brazilian Portuguese
localization (`P09`), domain validation for items and authentication (`P13`),
the item registration notifier and screen (`P14`), and the presentation session
notifier, authentication form state, and sign-in/sign-up screens (`P15`).
The backend API is deployed live on Render with TLS/HTTPS, backed by PostgreSQL
hosted on Supabase (`P08`), with schema migrations, health checks, and item routes
verified in production. Remaining work before final acceptance includes the Flutter
HTTP adapters (`P04` and `P10`), item listing state and cards (`P11`), and
end-to-end screen navigation and dependency assembly (`P12`).

## Cloud Deployment and Public API

The backend API is deployed and accessible publicly:

- **Public Base URL:** `https://campus-lost-found-api-zv3r.onrender.com`
- **Health check:** `https://campus-lost-found-api-zv3r.onrender.com/health`
- **Public items endpoint:** `https://campus-lost-found-api-zv3r.onrender.com/items`
- **Database:** PostgreSQL on Supabase (project `mtcitijfwtdcrxepzqwp`)
- **Hosting:** Render Web Service (Free tier, Docker runtime)

Flutter builds use `--dart-define=API_BASE_URL=https://campus-lost-found-api-zv3r.onrender.com`
to connect to the live cloud backend.

## Planned features

- Shared cloud list of lost and found objects, newest first, with manual refresh.
- Object registration with required name, description, location, and status.
- Name limit of 60 characters, description limit of 200, and automatic creation time.
- Loading, empty, success, and error states, with retry and duplicate-submit protection.
- Material 3 interface in Brazilian Portuguese.
- Additional requested scope: account registration, sign-in, sign-out, session
  restoration, public browsing, and authenticated object publication.

## Team

| Member | Packages | Main responsibility |
| --- | --- | --- |
| Fabricio Fontenele Vieira | `P01`–`P04` | Authentication contracts and API, server-side sessions, and Flutter authentication adapter |
| Francisco Alves Ribeiro Neto | `P05`–`P08` | API foundation, PostgreSQL, object endpoints, deployment, and configuration |
| Ruan Pedro de Araujo Anjos | `P09`–`P12` | Flutter foundation, object models and adapter, listing, navigation, and integration |
| Willamy Josue Santos Serejo | `P13`–`P16` | Validation, object registration, sign-in/sign-up UI, presentation session state, README, and acceptance evidence |

The plan assigns each member four work packages totaling 16 relative effort
points, plus five acceptance checks. Estimates include implementation, testing,
module documentation, and review; they are not measured hours. Each author owns
their fixes, Ruan coordinates integration, and Willamy consolidates documentation
and evidence supplied by the team. Francisco handles SIGAA submission, with
Ruan as backup. Each member contributes identifiable commits and understands the
complete flow.

## Documentation

- [Official assignment](docs/pmob-aval2.pdf), in Portuguese.
- [Development plan](docs/development_plan.md), in Portuguese, with ownership,
  milestones, dependencies, acceptance checks, and the proposed cloud service.
- [Authentication contracts and progress](docs/authentication.md), with Fabricio's
  P01–P03 implementation, configuration, test instructions, and remaining dependencies.
- [Validation, forms, and presentation session state](docs/validation_and_forms.md),
  with Willamy's P13–P15 implementation and acceptance check evidence.
- [Agent instructions](AGENTS.md), in English.

## Technical direction

Use Flutter/Dart, Material 3, `ChangeNotifier`, constructor injection, and
`flutter_test`. Organize object and authentication features into presentation,
domain, and data responsibilities. Authentication will use a separate
team-owned Dart HTTP API, with server-side password hashing and revocable opaque
sessions. The Flutter app accesses this API for authentication and object data;
it does not connect directly to credential tables or use Supabase Auth.

Render Free is proposed for hosting the API and Supabase Free only for PostgreSQL,
subject to the feasibility check described in the plan. Keep database integration
behind SQL contracts so the database host can be replaced independently of
authentication. Use maintained cryptographic libraries rather than implementing
password hashing or token-generation algorithms.

Production data must use real remote persistence. Unit and widget tests isolate
external services. Use demonstration objects and accounts without personal data.
Keep private credentials, authentication tokens, and generated build artifacts
out of version control. The Flutter app receives only the public `API_BASE_URL`;
database credentials stay in the API's environment. Reproducible API and database
setup must be documented when the integration is implemented.

## Development checks

Run these from the repository root to verify the Flutter application:

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

Build and run the configured mobile target with the documented cloud parameters
before delivery once the HTTP adapters (`P04`, `P10`), screen integration (`P12`),
and cloud deployment (`P08`) are connected.

From `api/`, run `dart pub get`, `dart analyze`, and `dart test`, and verify
HTTPS deployment.

## Academic delivery

Submit the public GitHub repository URL and all members' full names through SIGAA
by **November 8, 2026, at 23:59**. The internal target is 20:00 on the same day.
Keep source files, necessary configuration and resources, and documentation in
the repository. APKs, AABs, IPAs, executables, build directories, tool caches, and
private credentials must remain outside the tracked files.
