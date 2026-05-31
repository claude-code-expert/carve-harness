# Tech Stack — Dart / Flutter

> Detected stack. Trim/extend to match reality.

## Core
- **Language**: Dart 3.x (sound null safety)
- **SDK**: Flutter stable channel (if a Flutter app); otherwise the Dart SDK
- **Package manager**: pub (`pubspec.yaml`; `pubspec.lock` committed for apps)
- **Build mode**: `debug` for dev, `release`/`profile` for ship

## Quality Tooling
- **Lint/analyze**: `flutter analyze` / `dart analyze` with `flutter_lints` (or `lints`) + a tuned `analysis_options.yaml`
- **Format**: `dart format`
- **Test**: `flutter test` (widget/unit) / `dart test` (pure Dart)
- **Validation**: validate external input (JSON, args, platform channels) at the boundary

## Frontend / App (if a Flutter app)
- State management: Riverpod **or** Bloc — pick one, keep it consistent
- Models: immutable, generated with `freezed` + `json_serializable`
- Navigation: a single router (e.g. `go_router`) — no ad-hoc `Navigator.push` sprawl
- Theming: a centralized `ThemeData`; no inline magic colors/sizes

## Backend / Pure Dart (if applicable)
- HTTP: a typed client (`dio`/`http`) wrapped in a service layer — no raw calls in widgets
- Persistence: `drift` or `sqflite` — no raw SQL strings scattered in app code
- DI: a single composition root (e.g. `get_it`/Riverpod providers)

## Rules
- No library outside this stack without a stated rationale and user approval.
- Pin major versions; document any upgrade in the changelog.
