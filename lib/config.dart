/// n8n production webhook URL, passed at build/run time:
///   flutter run --dart-define=WATCHPOST_API=https://YOUR-N8N/webhook/watchpost
/// When empty the app runs in local demo mode (no server).
const String kApiUrl = String.fromEnvironment('WATCHPOST_API');

/// Seconds between checks of n8n while the app is open. EVERY check is one n8n
/// execution (240/hour at 15 s, 60/hour at 60 s). Raise it on n8n Cloud; lower it
/// (down to 10) only when n8n is self-hosted. Pull down on the Alerts list to refresh now.
///   flutter run --dart-define=POLL_SECONDS=30
const int _pollSecondsRaw = int.fromEnvironment('POLL_SECONDS', defaultValue: 60);
final int kPollSeconds = _pollSecondsRaw < 10 ? 10 : _pollSecondsRaw;
