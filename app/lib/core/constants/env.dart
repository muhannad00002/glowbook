/// Build-time configuration. Nothing secret lives in the app — only the public API
/// origin and the public web origin used when sharing booking links.
///
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
///   flutter build web --dart-define=API_BASE_URL=https://your-api.vercel.app \
///                     --dart-define=APP_BASE_URL=https://your-app.vercel.app
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  static const appBaseUrl = String.fromEnvironment('APP_BASE_URL', defaultValue: 'http://localhost:8080');

  /// The salon this app runs (Glowbook is deployed for a single salon).
  static const salonSlug = String.fromEnvironment('SALON_SLUG', defaultValue: 'maison-beauty');

  /// Shows the demo-account shortcuts on the sign-in screen. Off for production builds.
  static const showDemoAccounts = bool.fromEnvironment('SHOW_DEMO_ACCOUNTS', defaultValue: true);
}
