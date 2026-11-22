/// Build-time settings for the cloud backend.
///
/// Nothing secret lives in the code. Pass the values when building:
///
///     flutter run -d chrome \
///       --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
///       --dart-define=SUPABASE_KEY=sb_publishable_...
///
/// The URL and publishable (anon) key are public by design: Row Level
/// Security on the server is what keeps each runner's data private. Without
/// them the app runs exactly as before, local-only, with no sign-in.
library;

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

/// True when this build can sign in and sync.
const backendConfigured = supabaseUrl != '' && supabaseKey != '';

/// Sign in with Apple needs a paid Apple Developer account, so it stays off
/// until that is set up: add --dart-define=APPLE_SIGN_IN=true.
const appleSignInEnabled = bool.fromEnvironment('APPLE_SIGN_IN');

/// Where the sign-in page sends the iPhone app back to (registered in
/// ios/Runner/Info.plist and in Supabase's redirect URLs).
const nativeAuthRedirect = 'com.glorycomrade.setlisttracker://login-callback';
