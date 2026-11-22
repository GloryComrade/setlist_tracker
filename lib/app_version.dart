/// The app's version, as in pubspec.yaml (a test keeps the two the same).
/// A build can pass its own with --dart-define=APP_VERSION=1.0.1+7.
const kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0+1',
);
