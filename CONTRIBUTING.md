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

### CI/CD Workflow (`release.yml`)

The `Release APK` GitHub Actions workflow triggers automatically on any tag push
matching `v*` (e.g. `v1.0.1`), or manually via **Run workflow** (`workflow_dispatch`)
with optional draft or pre-release flags.

The workflow:
1. Runs code analysis (`dart analyze`) and unit/widget test suites (`flutter test`).
2. Configures release signing if keystore secrets are present (falling back to debug signing if not configured).
3. Builds both universal and split-per-ABI APKs:
   - `pesaflow-<version>-universal.apk`: Universal build for any Android device.
   - `pesaflow-<version>-arm64-v8a.apk`: Optimized for modern 64-bit devices.
   - `pesaflow-<version>-armeabi-v7a.apk`: Optimized for older 32-bit devices.
   - `pesaflow-<version>-x86_64.apk`: For emulators and x86_64 devices.
4. Generates a `pesaflow-<version>-checksums-sha256.txt` file for checksum verification.
5. Extracts release notes automatically from `CHANGELOG.md` via `scripts/changelog-section.sh`.
6. Stores APKs in workflow run artifacts (`actions/upload-artifact@v4`).
7. Publishes a GitHub Release with attached APKs and checksums.

#### Release Signing Configuration (Optional)

To sign release builds with a production keystore, configure the following GitHub Repository Secrets:
- `KEYSTORE_BASE64`: Base64 encoded `.jks` or `.keystore` file (`base64 -w 0 upload-keystore.jks`).
- `KEYSTORE_PASSWORD`: Keystore password.
- `KEY_ALIAS`: Keystore key alias.
- `KEY_PASSWORD`: Keystore key password.

For local signed builds, copy `android/key.properties.example` to `android/key.properties` and provide your keystore credentials.

To preview the release notes for a version:

```bash
scripts/changelog-section.sh 1.2.0
```
