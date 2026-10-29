# Contributing

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

SMS capture only works on a physical Android device with the app installed and
SMS permission granted.

## Before opening a pull request

Run all three checks:

```bash
dart analyze lib test
dart format --set-exit-if-changed lib test
flutter test
```

Add or update tests for behaviour changes. Parser changes should include a
sample in `test/fixtures/sms_corpus.dart` and an assertion in the relevant
parser test.

## Code style

- Keep money in integer cents; format through `currency_formatter.dart`.
- Take colours from `context.appColors` and text styles from `theme.textTheme`
  or `context.ts(...)`. Do not branch on `context.isDark` in screen code.
- Use `kSpacing*` and `AppTheme.radius*` instead of raw numbers.
- Prefer `TactileSpringContainer` for tappable surfaces and `CustomToast` for
  feedback. Do not add a second haptic or scale on top of it.
- Avoid perpetual animations. Ambient effects should settle once or run only
  while the user is interacting.
- Do not hand-edit generated `*.g.dart` files.

## Commit messages

Use a short imperative subject, optionally with a scope:

```
fix(sms): keep fee when "Charges" has no colon
feat(budgets): sweep emergency leftovers into savings
refactor(theme): replace raw colours with semantic tokens
```

Avoid subjects like "update screens" or "fix stuff"; say what changed and why.
Keep unrelated changes in separate commits.

## Releases

Versions follow [Semantic Versioning](https://semver.org/). The current version
is in `pubspec.yaml`; every release gets a dated section in `CHANGELOG.md`.

1. Add the release notes under a new `## [x.y.z] - YYYY-MM-DD` heading in
   `CHANGELOG.md`, and update the comparison links at the bottom.
2. Make sure `main` is green and the working tree has no unrelated changes.
3. Run the release script:

   ```bash
   scripts/release.sh 1.2.0
   ```

   It updates the version and build number in `pubspec.yaml`, commits the
   changelog and version bump, and creates an annotated `v1.2.0` tag.
4. Push the commit and tag:

   ```bash
   git push origin main --follow-tags
   ```

   Or run `scripts/release.sh 1.2.0 --push` to push immediately.

The `Release` GitHub Actions workflow runs on the tag, builds the split APKs,
extracts the matching `CHANGELOG.md` section, and publishes a GitHub Release.
If the changelog section is missing, the workflow fails instead of publishing
empty notes.

To preview the notes for a version:

```bash
scripts/changelog-section.sh 1.2.0
```
