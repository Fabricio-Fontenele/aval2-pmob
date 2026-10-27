# Campus Lost and Found

Academic project for the second assessment of the Mobile Programming course at
Universidade Estadual do Piauí (UESPI). The planned application uses Flutter and
Dart to publish and browse lost and found objects in the university community.

## Project status

The repository currently contains the assignment, development plan, agent
instructions, and repository configuration. The Flutter application has not been
scaffolded, and no cloud service has been provisioned. Build, execution, and cloud
setup instructions will be added with their implementations.

## Planned features

- Shared cloud list of lost and found objects, newest first, with manual refresh.
- Object registration with required name, description, location, and status.
- Name limit of 60 characters, description limit of 200, and automatic creation time.
- Loading, empty, success, and error states, with retry and duplicate-submit protection.
- Material 3 interface in Brazilian Portuguese.
- Additional requested scope: account registration, sign-in, sign-out, session
  restoration, public browsing, and authenticated object publication.

## Team

| Member | Main responsibility |
| --- | --- |
| Fabricio | Application foundation, authentication UI, session state, and integration |
| Francisco | Cloud storage, authentication adapters, and remote access rules |
| Ruan | Object listing, navigation, and README consolidation |
| Willamy | Object registration, validation, and acceptance checks |

Replace the short names with every member's full name before academic submission.
Each member must contribute identifiable commits and understand the complete flow.

## Documentation

- [Official assignment](docs/pmob-aval2.pdf), in Portuguese.
- [Development plan](docs/development_plan.md), in Portuguese, with ownership,
  milestones, dependencies, acceptance checks, and the proposed cloud service.
- [Agent instructions](AGENTS.md), in English.

## Technical direction

Use Flutter/Dart, Material 3, `ChangeNotifier`, constructor injection, and
`flutter_test`. Organize object and authentication features into presentation,
domain, and data responsibilities. Supabase Free is proposed for data and
authentication, subject to the feasibility check described in the plan.

Production data must use real remote persistence. Unit and widget tests isolate
external services. Use demonstration objects and accounts without personal data.
Keep private credentials, authentication tokens, and generated build artifacts
out of version control. Public client configuration and reproducible cloud setup
must be documented when the integration is implemented.

## Development checks

Once the Flutter application exists, run these from its root:

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

Build and run the configured mobile target with the documented cloud parameters
before delivery. These commands have not been run against an application yet;
there is no `pubspec.yaml` in the current project.

## Academic delivery

Submit the public GitHub repository URL and all members' full names through SIGAA
by **November 8, 2026, at 23:59**. The internal target is 20:00 on the same day.
Keep source files, necessary configuration and resources, and documentation in
the repository. APKs, AABs, IPAs, executables, build directories, tool caches, and
private credentials must remain outside the tracked files.
