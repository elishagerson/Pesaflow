/// The current semantic application version.
///
/// Can be overridden at build time via `--dart-define=APP_VERSION=x.y.z`.
/// Defaults to the version matching `pubspec.yaml`.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.1',
);
