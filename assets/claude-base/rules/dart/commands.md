# Commands — Dart / Flutter

> Canonical commands. Use these names; don't invent ad-hoc variants.
> `{{PKG_MANAGER}}` defaults to `flutter`; for a pure-Dart package use `dart` instead.

## Daily
| Task | Command |
|------|---------|
| Get deps | `{{PKG_MANAGER}} pub get` |
| Run | `{{PKG_MANAGER}} run`  (Dart pkg: `dart run`) |
| Build | `{{PKG_MANAGER}} build <target>`  (e.g. `apk`, `ios`, `web`) |
| Upgrade deps | `{{PKG_MANAGER}} pub upgrade` |

## Quality (run before commit)
| Task | Command |
|------|---------|
| Analyze | `{{LINT_CMD}}`  (`{{PKG_MANAGER}} analyze`; Dart pkg: `dart analyze`) |
| Format | `{{FORMAT_CMD}}`  (`dart format .`) |
| Tests | `{{TEST_CMD}}`  (`{{PKG_MANAGER}} test`; Dart pkg: `dart test`) |

## Notes
- "Always run tests before committing" → analyze + format + test all clean.
- Regenerate codegen after model changes: `dart run build_runner build --delete-conflicting-outputs`.
- Long-running integration tests may be skipped locally but must pass in CI.
