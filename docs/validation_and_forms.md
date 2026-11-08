# Validation, forms, and presentation session state

This document records Willamy's implementation and verification evidence for
work packages `P13`, `P14`, and `P15`, plus the acceptance checks `A03`, `A04`,
`A05`, `A07`, and `A11` defined in the [development plan](development_plan.md).

## Scope and package status

| Package | Scope | Evidence in repository | Status |
| --- | --- | --- | --- |
| `P13` | Domain validation rules for object registration and authentication | [`ItemInputValidator`](../lib/features/lost_found/domain/item_input_validator.dart), [`ItemStatus`](../lib/features/lost_found/domain/item_status.dart), [`AuthInputValidator`](../lib/features/auth/domain/auth_input_validator.dart), and unit tests under `test/features/*/domain/` | Completed |
| `P14` | Object registration notifier and Material 3 form screen | [`ItemFormNotifier`](../lib/features/lost_found/presentation/item_form_notifier.dart), [`ItemFormScreen`](../lib/features/lost_found/presentation/item_form_screen.dart), and tests under `test/features/lost_found/presentation/` | Completed |
| `P15` | Presentation session notifier, local authentication form notifier, sign-in screen, and sign-up screen | [`AuthSessionNotifier`](../lib/features/auth/presentation/auth_session_notifier.dart), [`AuthFormNotifier`](../lib/features/auth/presentation/auth_form_notifier.dart), [`LoginScreen`](../lib/features/auth/presentation/login_screen.dart), [`RegisterScreen`](../lib/features/auth/presentation/register_screen.dart), and tests under `test/features/auth/presentation/` | Completed |
| `P16` | Consolidated `README.md` and team acceptance evidence | Root [`README.md`](../README.md) and this verification record | In progress (final end-to-end mobile run awaits `P04` and `P10`–`P12`) |

## Domain validation contracts (`P13`)

Domain validators are pure Dart classes with no Flutter, HTTP, or cloud SDK
imports. Their rules match the server-side validation in `api/`:

- **Object registration (`ItemInputValidator`):**
  - `name`: required after `trim()`, at most `60` Unicode code points (`runes.length`).
  - `description`: required after `trim()`, at most `200` Unicode code points (`runes.length`).
  - `location`: required after `trim()`.
  - `status`: required; restricted to `ItemStatus.lost` (*Perdido*) or `ItemStatus.found` (*Encontrado*).
  - Validated inputs return an immutable `ValidatedItemInput` with trimmed text fields.
- **Authentication (`AuthInputValidator`):**
  - `email`: normalized with `trim().toLowerCase()`, validated against practical ASCII local-part and dotted domain label rules (`<= 254` characters total).
  - `password` (registration): required, not blank/whitespace-only, and at least `8` Unicode code points (`runes.length`). Original characters, including leading or trailing spaces, are preserved without trimming.
  - `password` (login): required and non-blank, preserving original characters.
  - `passwordConfirmation`: validated locally against `password` during registration and never sent to `AuthRepository`.

## Presentation state and rebuild boundaries (`P14` and `P15`)

- **`ItemFormNotifier`:** manages `idle`, `submitting`, `succeeded`, and `failed` states for object publication. Rejects concurrent `submit()` calls while a request is in flight, exposes server-returned `fieldErrors`, and triggers `onUnauthorized` when the repository reports `401` (`isUnauthorized`).
- **`AuthSessionNotifier`:** tracks `restoring`, `authenticated`, `unauthenticated`, and `failure` states. Uses an internal epoch counter (`_sessionEpoch`) so stale `restoreSession()` or `logout()` completions cannot overwrite newer authentication state or publish updates after `dispose()`.
- **`AuthFormNotifier`:** keeps transient submission progress and error messages local to `LoginScreen` and `RegisterScreen` so typing or submitting credentials does not trigger global application rebuilds.
- **Narrow `ListenableBuilder` scopes:** in `ItemFormScreen`, `LoginScreen`, and `RegisterScreen`, `TextFormField` widgets remain outside the notifier listener. Only the action buttons, progress indicators, and error cards rebuild when submission state changes.

## Acceptance checks owned by Willamy

| Check | Requirement | Automated coverage | Current status and remaining dependency |
| --- | --- | --- | --- |
| `A03`: Field validation | `RF02` | `test/features/lost_found/domain/item_input_validator_test.dart`, `test/features/lost_found/presentation/item_form_screen_test.dart` (`60`/`200` pass, `61`/`201` fail, blank/whitespace rejected without calling repository) | Verified in domain and widget tests |
| `A04`: Successful object registration | `RF02`, `RF04`, `AU04` | `test/features/lost_found/presentation/item_form_notifier_test.dart`, `test/features/lost_found/presentation/item_form_screen_test.dart` (confirmed save pops `true` and invokes `onItemSaved`) | Form and API verified; live refresh on the mobile list screen awaits `P10`–`P12` |
| `A05`: Repeated taps | `RF03`, `RF04` | `test/features/lost_found/presentation/item_form_notifier_test.dart`, `test/features/lost_found/presentation/item_form_screen_test.dart` (concurrent taps produce a single repository call while loading indicator is visible) | Verified in notifier and widget tests |
| `A07`: Write failure and retry | `RF03` | `test/features/lost_found/presentation/item_form_notifier_test.dart`, `test/features/lost_found/presentation/item_form_screen_test.dart` (filled values preserved on failure, error card and server `fieldErrors` shown, retry succeeds) | Verified in notifier and widget tests |
| `A11`: Interface and lifecycle | `RNF01`, `RF04`, `AU01`–`AU05` | `test/features/lost_found/presentation/item_form_screen_test.dart`, `test/features/auth/presentation/auth_screens_test.dart` (`320x480` viewport, `1.5x` text scaling, keyboard `viewInsets`, back navigation, and disposal while pending without overflow or exception) | Verified on `ItemFormScreen`, `LoginScreen`, and `RegisterScreen`; final check on `ItemListScreen` awaits `P11`/`P12` |
