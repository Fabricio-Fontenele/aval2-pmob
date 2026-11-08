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

## Scope: official assignment vs. additional authentication

### Official assignment requirements (`RF01`–`RF05`, `RNF01`–`RNF03`)
- Shared cloud list of lost and found objects, ordered newest first, with manual refresh and visual distinction between *Perdido* (`lost`) and *Encontrado* (`found`).
- Object registration enforcing required fields, trimmed non-blank inputs, a 60-character limit for object name, a 200-character limit for description, required location and status, and automatic server-assigned creation timestamp.
- Explicit loading, empty, success, and recoverable error states with retry actions and duplicate-submit protection.
- Responsive Material 3 user interface in Brazilian Portuguese (`pt-BR`).

### Additional requested scope (`AU01`–`AU05`)
- **Custom authentication (`AU01`–`AU03`):** account registration and login by email and password (`>= 8` Unicode code points, local password confirmation), Argon2id password hashing on the custom Dart API, and revocable opaque bearer sessions persisted in PostgreSQL. Neither the Flutter app nor the API uses Supabase Auth.
- **Publication authorization (`AU04`):** browsing and refreshing the object list remain public (`GET /items`), while publishing an object (`POST /items`) requires a valid session token and assigns authorship on the server from the authenticated session.
- **Navigation and evaluation flow (`AU05`):** sign-in and account creation screens are accessible from the application flow, returning the user to the requested action after authentication and allowing sign-out at any time.

## Evaluation guide and demonstration account

Evaluators do not need team credentials, database secrets, or a personal email
inbox. Demonstration accounts become active immediately upon registration without
email confirmation:

1. **Run the Flutter app against the public cloud API:**
   ```sh
   flutter pub get
   flutter run --dart-define=API_BASE_URL=https://campus-lost-found-api-zv3r.onrender.com
   ```
   *(To build a local debug APK on Android: `flutter build apk --debug --dart-define=API_BASE_URL=https://campus-lost-found-api-zv3r.onrender.com`).*
2. **Browse public items:** the home screen loads existing records from `GET /items` ordered newest first and supports manual refresh.
3. **Create a demonstration account (`AU01`):**
   - Open the sign-in/registration action and select **Criar uma conta**.
   - Enter a test address such as `avaliador1@example.test` (never use personal data) and a password with at least 8 characters (for example, `SenhaDemo123`), repeat it in **Confirmar senha**, and tap **Criar conta**.
   - The API creates the user and session atomically (`POST /auth/register`) and signs the app in immediately.
4. **Publish a lost or found object (`RF02`, `AU04`):**
   - Fill **Nome do objeto** (`<= 60` characters), **Descrição** (`<= 200` characters), **Local**, and **Situação** (*Perdido* or *Encontrado*), then tap **Salvar objeto**.
   - Once the remote save succeeds, the list refreshes so the new record appears at the top.
5. **Sign out and verify persistence (`AU03`, `RF05`):**
   - Trigger sign-out (`POST /auth/logout`) to revoke the current token on the server.
   - Restart the app or refresh from another installation to confirm that published objects remain publicly listed from PostgreSQL.

> **Free-tier cold start note:** Render Free may spin down the container after periods of inactivity. The first request after an idle period can take 30–60 seconds while the container wakes up; if a timeout occurs, use the **Tentar novamente** action in the UI without duplicating writes.

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
