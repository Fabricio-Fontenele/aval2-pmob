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
verified in production. The Flutter authentication HTTP adapter and secure token
store (`P04`) are implemented and covered by isolated tests. The item HTTP
adapter (`P10`), the listing notifier, cards, and manual refresh (`P11`), and the
dependency assembly with the protected navigation flow (`P12`) are implemented as
well, so the application runs the complete flow against the deployed API.
Remaining work before final acceptance is execution evidence: running the quality
gates and the acceptance checks on a device against the cloud API.

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
  P01–P04 implementation, configuration, adapter assembly guide, test instructions,
  and remaining acceptance checks.
- [Validation, forms, and presentation session state](docs/validation_and_forms.md),
  with Willamy's P13–P15 implementation and acceptance check evidence.
- [Objects, listing, and flow integration](docs/items_and_navigation.md), in
  Portuguese, with Ruan's P10–P12 implementation: item HTTP adapter, listing
  state and screen, dependency assembly, navigation rules, and test mapping.
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

The local baseline is Flutter 3.47.1 with Dart 3.13.1. The Dart minimum is
`^3.13.1`, matching the supported 3.13 language features used by this application.
The lockfile includes `http` and `flutter_secure_storage` 10.x; the latter matches
the existing Android compile SDK 36 and minimum SDK 24.

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

Flutter verification summary recorded before `P10`-`P12`:
- `dart format --output=none --set-exit-if-changed lib test`: clean across Flutter source and tests.
- `flutter analyze`: no issues found.
- `flutter test`: 111 automated unit, notifier, adapter, and widget tests passing (`test/app/`, `test/features/lost_found/`, and `test/features/auth/`).

The `P10`-`P12` modules added the item HTTP adapter, listing notifier, listing
screen, and navigation flow tests (`test/features/lost_found/data/`,
`test/features/lost_found/presentation/item_list_*`, and `test/app/`). The three
gates above must be run again to record the updated results.

Build and run the configured mobile target with the documented cloud parameters
before delivery:

```sh
flutter run --dart-define=API_BASE_URL=https://campus-lost-found-api-zv3r.onrender.com
```

Note that `/android/` and `/linux/` are not tracked in this repository. On a
clean clone, create the platform project for the target before building:

```sh
flutter create --platforms=android .
```

From `api/`, run `dart pub get`, `dart analyze`, and `dart test`, and verify
HTTPS deployment (see [`api/README.md`](api/README.md) and
[`docs/authentication.md`](docs/authentication.md)).

## Acceptance verification matrix (`P16`)

Each member owns five acceptance checks defined in the
[development plan](docs/development_plan.md#matriz-de-aceite-e-testes):

| Check | Owner | Current evidence and status |
| --- | --- | --- |
| `A01`: List content and ordering | Ruan | API ordering (`created_at DESC`) verified in `api/test/routes/item_routes_test.dart`; cards, status distinction, and newest-first order covered in `test/features/lost_found/presentation/item_list_screen_test.dart` and `test/features/lost_found/data/http_item_repository_test.dart` |
| `A02`: Empty state and manual refresh | Ruan | Empty state, progress indication, and manual refresh covered in `test/features/lost_found/presentation/item_list_notifier_test.dart` and `item_list_screen_test.dart` |
| `A03`: Field validation (`60`/`200` limits, blank rejection) | Willamy | Verified in `test/features/lost_found/domain/item_input_validator_test.dart` and `test/features/lost_found/presentation/item_form_screen_test.dart` |
| `A04`: Successful object registration | Willamy | Form submission (`P14`) and API persistence (`P07`/`P08`) verified; list update after saving covered in `test/app/navigation_flow_test.dart`; device run against the cloud API pending |
| `A05`: Repeated submit protection | Willamy | Verified in `test/features/lost_found/presentation/item_form_notifier_test.dart` and `item_form_screen_test.dart` |
| `A06`: Read failure and retry | Ruan | Failure translation in `test/features/lost_found/data/http_item_repository_test.dart`; message and retry recovery in `item_list_notifier_test.dart` and `item_list_screen_test.dart` |
| `A07`: Write failure and retry | Willamy | Verified in `test/features/lost_found/presentation/item_form_notifier_test.dart` and `item_form_screen_test.dart` |
| `A08`: Save succeeded, refresh failed | Ruan | Confirmed save with failed refresh, its distinct notice, and a retry that only reads again covered in `test/app/navigation_flow_test.dart` and `item_list_notifier_test.dart` |
| `A09`: Persistence and cross-installation sharing | Francisco | Live PostgreSQL persistence and public `GET /items` verified in `P08`; two-installation mobile run pending |
| `A10`: Remote access rules | Francisco | Verified in `api/test/routes/item_routes_test.dart` and `api/test/db/migrator_test.dart` |
| `A11`: Material 3 UI, pt-BR, small screen, keyboard, and disposal | Willamy | Verified for `ItemFormScreen`, `LoginScreen`, and `RegisterScreen` in widget tests; `ItemListScreen` covered for `320x480`, `1.5x` text scaling, and disposal while reading in `item_list_screen_test.dart` |
| `A12`: Reproducible clean-clone evaluation | Francisco | API and cloud deployment documented; all Flutter modules implemented; clean-clone run pending, including the untracked platform project step documented above |
| `A13`: User registration validation and atomic creation | Fabricio | API, presentation, and `P04` HTTP adapter have isolated tests; real PostgreSQL and integrated mobile acceptance remain pending |
| `A14`: Sign-in and sign-out | Fabricio | `P04` tests cover Bearer requests, secure token storage, definitive rejection, and retry; sign-in and sign-out from the listing covered in `test/app/navigation_flow_test.dart`; real-device flow pending |
| `A15`: Session restoration and expiration | Fabricio | API, notifier, and `P04` tests cover remote validation, rejection, outages, and stale responses; actual app/API restart acceptance remains pending |
| `A16`: Protected navigation flow | Ruan | Sign-in request before publishing, return to the requested screen, cancellation, and blocking after sign-out covered in `test/app/navigation_flow_test.dart` |
| `A17`: Authentication concurrency and disposal | Fabricio | API/presentation tests plus `P04` regression tests for logout during pending login/storage and late replies; final integrated acceptance pending on a device |
| `A18`: Account data and hash/token confidentiality | Fabricio | API hash/serialization tests and `P04` storage channel tests; deployment logs, database permissions, and actual device storage still require inspection |
| `A19`: Server-side validation and rate limits | Francisco | Verified in `api/test/auth/auth_attempt_limiter_test.dart` and `api/test/routes/item_routes_test.dart` |
| `A20`: Cloud infrastructure and restart durability | Francisco | Verified live on Render + Supabase PostgreSQL (`P08`) |

## Academic delivery

Submit the public GitHub repository URL and all members' full names through SIGAA
by **November 8, 2026, at 23:59**. The internal target is 20:00 on the same day.
Keep source files, necessary configuration and resources, and documentation in
the repository. APKs, AABs, IPAs, executables, build directories, tool caches, and
private credentials must remain outside the tracked files.
