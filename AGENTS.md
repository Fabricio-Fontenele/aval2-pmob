# Project Instructions

## Scope and sources of truth

This is an academic lost-and-found application for the university community.
These instructions apply throughout the workspace.

At the time this file was created, the workspace had no Flutter scaffold,
`pubspec.yaml`, dependency lockfile, analyzer configuration, source code, tests,
or official requirements document. Git metadata was also uninitialized.
The structure below is a development convention, not an existing implementation;
no cloud provider or third-party dependency has been selected.

Before each task, inspect the current files, applicable nested instructions,
dependency manifest, configuration, and available requirements. Once an official
academic requirements document is available, read it before changing application
behavior and treat it as the behavioral source of truth. Until then, use the
product contract below. Surface material conflicts with explicit user decisions
instead of silently changing requirements or inventing missing document paths.

Complete authorized work through relevant verification without intermediate
approval stops for routine implementation choices. Keep changes within the
requested scope; documentation tasks do not authorize application scaffolding.

## Product contract

Implement only the requested part of these required capabilities:

- List lost and found objects, ordered by creation date and time, newest first.
- Register objects with validation and persist them remotely in the cloud.
- Support manual list refresh and refresh the list after successful registration.
- Visually distinguish lost and found objects, including a readable status label.
- Expose loading, empty, success, and error states with actionable feedback.
- Handle asynchronous failures and allow users to retry failed operations.

Registration must enforce the following rules in reusable domain validation;
form fields display the corresponding errors:

| Field | Validation or behavior |
| --- | --- |
| Object name | Required; at most 60 characters |
| Description | Required; at most 200 characters |
| Location | Required |
| Status | Required; exactly lost or found |
| Creation date and time | Assigned automatically and persisted with the record |

Reject blank required text, including whitespace-only input. Keep length limits
and status rules consistent between validation, widgets, and stored data.
Use English identifiers for status values and translate their display labels.

Authentication, editing, deletion, image uploads, notifications, and advanced
search require an explicit request. Production persistence must use a cloud
service compatible with the required free plan. Hardcoded records and local-only
storage cannot replace remote persistence; fakes belong in tests.

## Stack and language

- Use Dart with sound null safety, Flutter, Material 3, and `flutter_test`.
- Prefer `ChangeNotifier` for presentation state when sufficient; justify another
  approach with a concrete need before introducing its dependency.
- Prefer SDK capabilities and existing dependencies. Add packages, code generation,
  or tools only to solve an actual requirement; respect the manifest's SDK range
  and use stable features supported by that range.
- Write source code, identifiers, technical comments, documentation, test
  descriptions, and commit messages in English. User-facing application text
  must be in Brazilian Portuguese; communication with the user may also use it.
- Follow [Effective Dart](https://dart.dev/effective-dart/style): `snake_case`
  for source files and directories; `UpperCamelCase` for classes, abstract
  classes, enums, and other types; `lowerCamelCase` for variables, functions,
  methods, properties, constants, and enum values. Prefix library-private
  members with `_` and use descriptive names without ambiguous abbreviations.

## Architecture and code ownership

Apply Clean Code, SOLID, Clean Architecture, DRY, KISS, YAGNI, Separation of
Concerns, Dependency Inversion, Composition over Inheritance, and High Cohesion
and Low Coupling pragmatically. Choose the smallest design that separates real
responsibilities; avoid speculative extension points and design patterns.

For new features, prefer this organization, creating directories only when they
contain necessary code:

```text
lib/
  main.dart
  features/
    <feature_name>/
      presentation/
      domain/
      data/
test/                 # Mirror relevant production paths; use *_test.dart.
integration_test/     # Add only when end-to-end coverage is needed.
```

- **Domain:** pure Dart entities, business rules, and validation. It must not
  import Flutter, presentation code, cloud SDKs, or data implementations.
- **Presentation:** screens, widgets, forms, and narrowly scoped notifiers.
  Invoke domain behavior and injected contracts; keep persistence calls and
  complex business rules out of widgets and `State` objects.
- **Data:** remote sources, serialization, repository implementations, and
  translation of service failures into errors the application can handle.

Dependencies point inward: presentation and data may depend on domain; domain
depends on neither. When a persistence boundary needs a repository contract,
keep the contract in domain and its cloud implementation in data. Assemble
concrete dependencies at the application entry point and inject them through
constructors. Avoid circular imports and globally accessible mutable services.

Introduce interfaces, use cases, repositories, and separate transport models only
when they enforce a real boundary or support required testing. Avoid one-line
pass-through layers and inheritance hierarchies without useful behavior. Extract
shared code when actual reuse exists, rather than creating an empty core module.
See the [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
for guidance; this project's boundaries and dependency policy remain authoritative.

Keep functions small, cohesive, and at one abstraction level; prefer early returns
over deep nesting. Share duplicated rules, use named constants for meaningful
limits, and prefer immutable models, `final`, and `const` where appropriate.
Use precise types; justify `dynamic` and null assertions (`!`) with a demonstrable
guarantee. Make side effects explicit. Comments explain decisions rather than
restate code. Limit cleanup to code involved in the task.

## State, rebuilds, and lifecycle

Before changing stateful UI, identify which widgets consume each mutable value
and choose the narrowest listener boundary for each change.

- Keep transient field, focus, and component state near its consumers. Split
  notifiers by cohesive responsibility; avoid a single application-wide notifier.
- Represent operation loading, success, and failure explicitly without contradictory
  flags. Notify only when observable state changes; expose immutable state views.
- Scope `ListenableBuilder`, `ValueListenableBuilder`, or `AnimatedBuilder` to
  the dependent subtree. Keep independent children outside the builder or pass
  them through its `child` parameter where supported.
- A smaller widget alone does not isolate rebuilds if its listener remains at
  screen level. For independent mutable values, use focused listenables or
  notifiers when needed. Use `Selector` or `context.select` only if their library
  is already available and they provide a concrete benefit.
- Extract cohesive widgets with `const` constructors where possible. Changing one
  form field should leave unrelated expensive components independent; changing a
  submit button's loading indicator should not require a whole-screen listener.
- Keep `build()` focused on rendering. Start network and persistence work from
  lifecycle or event handlers, and keep heavy computation and repeated creation
  of expensive objects outside rebuilds.
- Give controllers, notifiers, subscriptions, and listeners a clear owner. Remove
  listeners, cancel subscriptions, and call `dispose()` where required. Check
  widget or context validity after asynchronous gaps before UI interactions;
  ensure notifiers cannot publish updates after disposal.
- Use `RepaintBoundary` only to isolate justified painting costs; it does not
  isolate rebuilds. Accept normal framework rebuilds and add further optimization
  only for a concrete benefit. Use DevTools when investigating costly rebuilds.

Follow the [Flutter performance guidance](https://docs.flutter.dev/perf/best-practices)
without introducing complex optimization machinery for hypothetical problems.

## Asynchronous operations, persistence, and security

- Use `Future`, `async`, and `await` for remote reads and writes. Keep the UI
  responsive and expose progress for relevant operations.
- Guard duplicate submissions in the state handler and disable the submit control
  while saving. Avoid duplicate reads and stale responses overwriting newer state.
- Handle expected network, timeout, and service errors at the appropriate boundary;
  provide safe, understandable feedback and a retry action. Do not silently catch
  arbitrary failures or present failed persistence as success.
- Confirm the remote save before reporting registration success. Refresh the list
  afterward. If saving succeeds but refreshing fails, preserve that distinction
  so retrying the refresh does not submit a duplicate object.
- Persist the automatic creation timestamp and use it consistently for ordering.
  Keep cloud SDK types and serialization out of the domain layer.
- Before choosing a cloud service, verify that the required reads, writes, and
  access model work within its current free plan. Keep integration in data and
  document execution parameters and setup in the project's technical documentation.
- Configure remote access rules for the intended operations and validate writes;
  unrestricted database access is not an acceptable substitute for configuration.
  Do not introduce authentication to solve this without a requirement or request.
- Distinguish public client configuration from private credentials. Supply private
  values through environment or platform configuration; never commit secrets,
  passwords, or tokens. Client bundles cannot keep private credentials secret.
- Use permitted demonstration data only. Collect item information rather than
  personal or sensitive information, and keep sensitive values out of logs.

## User interface

Use a consistent Material 3 theme and Brazilian Portuguese labels, validation
messages, and feedback. Adapt layouts to different screen sizes without overflow;
use `SafeArea` where insets matter. Preserve accessibility, readable contrast,
text scaling, and usable controls. Distinguish statuses using text as well as
visual styling. Keep forms clear and make loading, empty, success, and error
states understandable without unnecessary visual elements or extra features.

## Development and testing workflow

For features and fixes with testable behavior:

1. Read the requirements and existing implementation. Identify affected modules,
   state transitions, external boundaries, and widget rebuild scopes.
2. **RED:** write the smallest meaningful failing test and run it. Confirm it
   fails for the missing behavior, rather than a broken test environment.
3. **GREEN:** implement the simplest change that passes that test.
4. **REFACTOR:** improve cohesion and remove duplication while keeping tests green.
5. Review asynchronous effects, resource ownership, rebuild scope, and the final
   diff; run the relevant quality checks below before reporting completion.

Use `flutter_test` for unit, validation, notifier, widget, and component-interaction
tests. Place them under `test/` with `_test.dart` filenames, mirroring relevant
`lib/` paths. Add `integration_test/` and the Flutter SDK integration test tooling
only for required end-to-end journeys.

Test observable behavior, including required inputs, exact length boundaries,
invalid status, ordering, refresh, and post-registration updates when affected.
Cover loading transitions, failure and retry, and duplicate-submit prevention for
changed asynchronous flows. Add a regression test for each testable bug fix.
Use deterministic, independent tests with controlled time where needed and small
fakes at external boundaries; unit tests must not call live cloud services.
Use mocks only when needed and avoid assertions on private implementation details.
Documentation-only edits do not need tests that lock down prose.

## Quality gates and completion

Once a Flutter project exists, run these from its root after relevant code changes:

```sh
dart format .
flutter analyze
flutter test
```

Run focused tests during TDD, then the relevant suite. Inspect the formatting diff
and keep unrelated files outside the task. Resolve analyzer problems introduced
by the change and report existing failures separately; do not suppress diagnostics
to pass checks. When application code, dependencies, or platform configuration
changes, also build for a configured target with `flutter build <target>` and
verify startup and the affected flow with `flutter run -d <device_id>` when
available. Replace placeholders using actual project targets and connected devices.

Complete an implementation when requirements and layer boundaries hold, relevant
tests pass, the changed code is formatted and analyzer-clean, state observation
does not cause unnecessarily broad rebuilds, and no unjustified duplication,
exposed credentials, or temporary code remains. Report exactly which checks ran
and their outcomes. If scaffolding, configuration, tools, credentials, or devices
prevent a check, state that limitation rather than claim verification or success.

## Git and handoff

Suggest a cohesive English Conventional Commit message in the form
`type(scope): message`, using a short imperative description and a module-related
scope. Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`,
`build`, `ci`, and `style`.

Do not create commits, push, or perform destructive Git operations without explicit
authorization. Do not impose a branch strategy or initialize Git as an incidental
part of another task.

After an implementation, report concisely: **Summary**, **Files changed**,
**Tests**, **Architecture notes**, **Performance notes**, and **Suggested commit**.
State when architecture or performance notes are not applicable, and include
verification limitations. Explanations may be in Brazilian Portuguese; the
suggested commit message must remain in English.
