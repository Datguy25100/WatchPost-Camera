import 'package:intl/intl.dart';
import 'models.dart';

String formatTime(DateTime t) => DateFormat('HH:mm').format(t);
String formatDate(DateTime t) => DateFormat('MMM d, yyyy').format(t);

/// The AI sentence when n8n provided one, otherwise a plain description.
String describeAlert(AlertModel a) {
  final s = a.summary?.trim();
  if (s != null && s.isNotEmpty) return s;
  return '${a.kind.label} detected at ${a.cameraName}, ${formatTime(a.time)}';
}

// ---------- Camera address helpers ----------
final _hostPort = RegExp(r'^[A-Za-z0-9.\-]+(:\d{1,5})?$');
final _fullUrl = RegExp(r'^(https?|rtsp)://[^\s/]+', caseSensitive: false);
final _plainHttp = RegExp(r'^http://([A-Za-z0-9.\-]+(:\d{1,5})?)$', caseSensitive: false);

/// Cleans what the user typed. Returns '' when empty and null when it is not a
/// usable address. "http://192.168.1.50:8080/" becomes "192.168.1.50:8080".
String? cleanCameraAddress(String raw) {
  var v = raw.trim();
  while (v.endsWith('/')) {
    v = v.substring(0, v.length - 1);
  }
  if (v.isEmpty) return '';
  if (v.length > 200 || RegExp(r'\s').hasMatch(v)) return null;
  final plain = _plainHttp.firstMatch(v);
  if (plain != null) return plain.group(1);
  if (_fullUrl.hasMatch(v) || _hostPort.hasMatch(v)) return v;
  return null;
}

/// Hides a password inside rtsp://user:pass@host so it is never shown on screen.
String maskAddress(String address) =>
    address.replaceFirst(RegExp(r'//[^/@]*@'), '//***@');

/// Single-picture URL used for the in-app live view (IP Webcam serves /shot.jpg).
/// Null when we cannot build one (empty address, rtsp://, other camera brands).
Uri? liveShotUri(String address) {
  final a = address.trim();
  if (a.isEmpty || a.toLowerCase().startsWith('rtsp://')) return null;
  if (a.toLowerCase().startsWith('http')) {
    final u = Uri.tryParse(a);
    if (u == null || !u.hasAuthority) return null;
    final p = u.path;
    if (p.isEmpty || p == '/' || p == '/video') return u.replace(path: '/shot.jpg');
    return null;
  }
  final withPort = a.contains(':') ? a : '$a:8080';
  return Uri.tryParse('http://$withPort/shot.jpg');
}
