import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/speaker.dart';

class Assets {
  static const frontDoor = 'assets/images/front-door.jpg';
  static const gate = 'assets/images/gate.jpg';
  static const backyard = 'assets/images/backyard.jpg';
  static const night = 'assets/images/night-car.jpg';

  static const choices = <(String, String)>[
    ('Door', frontDoor),
    ('Gate', gate),
    ('Yard', backyard),
    ('Night', night),
  ];
}

/// App state. With an [ApiService] it syncs with the n8n backend (polling);
/// without one it runs in local demo mode with simulated alerts.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState(this._prefs, {ApiService? api, Speaker? speaker})
      : _api = api,
        _speaker = speaker {
    WidgetsBinding.instance.addObserver(this);
    _load();
    if (user != null) {
      _restartBackground();
      refresh();
    }
  }

  final SharedPreferences _prefs;
  final ApiService? _api;
  final Speaker? _speaker;
  final _rng = Random();

  bool get isRemote => _api != null;

  bool onboarded = false;
  bool speakAlerts = true;
  String? user;
  List<AlertModel> alerts = [];
  List<CameraModel> cameras = [];
  List<PersonModel> people = [];
  AlertModel? toast;
  bool syncing = false;
  bool offline = false;

  Timer? _bgTimer;
  Timer? _toastTimer;
  bool _synced = false;

  int get unseenCount => alerts.where((a) => !a.seen).length;
  bool get isSignedIn => user != null;

  AlertModel? alertById(String id) {
    for (final a in alerts) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ---------- Persistence (also used as offline cache in remote mode) ----------
  void _load() {
    onboarded = _prefs.getBool('onboarded') ?? false;
    speakAlerts = _prefs.getBool('speak') ?? true;
    user = _prefs.getString('user');
    _api?.token = _prefs.getString('token');
    if (isRemote && _api!.token == null) user = null;

    try {
      final rawAlerts = _prefs.getString('alerts');
      final rawCameras = _prefs.getString('cameras');
      final rawPeople = _prefs.getString('people');
      people = rawPeople == null
          ? []
          : (jsonDecode(rawPeople) as List)
              .map((e) => PersonModel.fromJson(e as Map<String, dynamic>))
              .toList();
      alerts = rawAlerts == null
          ? (isRemote ? [] : _seedAlerts())
          : (jsonDecode(rawAlerts) as List)
              .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
              .toList();
      cameras = rawCameras == null
          ? (isRemote ? [] : _seedCameras())
          : (jsonDecode(rawCameras) as List)
              .map((e) => CameraModel.fromJson(e as Map<String, dynamic>))
              .toList();
    } catch (_) {
      alerts = isRemote ? [] : _seedAlerts();
      cameras = isRemote ? [] : _seedCameras();
    }
  }

  void _save() {
    _prefs.setBool('onboarded', onboarded);
    _prefs.setBool('speak', speakAlerts);
    if (user == null) {
      _prefs.remove('user');
      _prefs.remove('token');
    } else {
      _prefs.setString('user', user!);
      final t = _api?.token;
      if (t != null) _prefs.setString('token', t);
    }
    // Snapshots (base64) can be tens of KB each; keep them out of the on-disk
    // cache. They are fetched again from the server after a restart.
    _prefs.setString(
        'alerts',
        jsonEncode(alerts
            .map((a) => (a.image.startsWith('data:') ? a.copyWith(image: '') : a).toJson())
            .toList()));
    _prefs.setString('cameras', jsonEncode(cameras.map((c) => c.toJson()).toList()));
    _prefs.setString('people', jsonEncode(people.map((p) => p.toJson()).toList()));
  }

  void _commit() {
    _save();
    notifyListeners();
  }

  /// Fire-and-forget server call (the UI already updated optimistically).
  void _push(Future<void> Function(ApiService api) call) {
    final api = _api;
    if (api == null) return;
    call(api).catchError((Object e) {
      if (e is ApiException && e.unauthorized) _expireSession();
    });
  }

  void _expireSession() {
    user = null;
    _api?.token = null;
    toast = null;
    _synced = false;
    _restartBackground();
    _commit();
  }

  // ---------- Auth / onboarding ----------
  void completeOnboarding() {
    onboarded = true;
    _commit();
  }

  /// Returns an error message, or null on success.
  Future<String?> signIn(String email, String password) async {
    final api = _api;
    if (api != null) {
      try {
        api.token = await api.login(email, password);
      } on ApiException catch (e) {
        return e.message;
      } catch (_) {
        return 'Cannot reach the server. Check your connection and API URL.';
      }
    }
    user = email;
    _synced = false;
    _restartBackground();
    _commit();
    if (api != null) await refresh();
    return null;
  }

  void signOut() {
    _push((api) => api.logout());
    user = null;
    toast = null;
    _synced = false;
    _restartBackground();
    // Keep token clear locally right away.
    _api?.token = null;
    _commit();
  }

  // ---------- Remote sync ----------
  Future<void> refresh() async {
    final api = _api;
    if (api == null || user == null || syncing) return;
    syncing = true;
    try {
      final data = await api.getState(
        have: [for (final a in alerts) if (a.image.startsWith('data:')) a.id],
      );
      final old = {for (final a in alerts) a.id: a};
      // The server leaves out snapshots we already have: keep our copy.
      final incoming = [
        for (final a in data.alerts)
          (a.image.isEmpty && old[a.id] != null) ? a.copyWith(image: old[a.id]!.image) : a
      ];
      final fresh = incoming.where((a) => !old.containsKey(a.id) && !a.seen).toList();
      final changed = _signature(incoming, data.cameras, data.people) !=
          _signature(alerts, cameras, people);
      final wasOffline = offline;
      alerts = incoming;
      cameras = data.cameras;
      people = data.people;
      offline = false;
      if (_synced && fresh.isNotEmpty) {
        _showToast(fresh.first);
        _announce(fresh.first);
      }
      _synced = true;
      // Only rebuild + write to disk when something actually changed.
      if (changed || fresh.isNotEmpty) {
        _commit();
      } else if (wasOffline) {
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (e.unauthorized) {
        _expireSession();
      } else {
        offline = true;
        notifyListeners();
      }
    } catch (_) {
      offline = true;
      notifyListeners();
    } finally {
      syncing = false;
    }
  }

  /// Cheap fingerprint used to skip UI rebuilds / disk writes when a poll brings nothing new.
  String _signature(List<AlertModel> a, List<CameraModel> c, List<PersonModel> p) {
    final b = StringBuffer();
    for (final x in a) {
      b
        ..write(x.id)
        ..write(':')
        ..write(x.seen)
        ..write(':')
        ..write(x.summary)
        ..write(':')
        ..write(x.image.length)
        ..write('|');
    }
    b.write(jsonEncode(c.map((x) => x.toJson()).toList()));
    b.write(jsonEncode(p.map((x) => x.toJson()).toList()));
    return b.toString();
  }

  /// Reads the alert sentence aloud (text-to-speech) when voice is on.
  void _announce(AlertModel alert) {
    if (speakAlerts) _speaker?.speak(describeAlert(alert));
  }

  void toggleSpeak() {
    speakAlerts = !speakAlerts;
    if (!speakAlerts) _speaker?.stop();
    _commit();
  }

  void _showToast(AlertModel alert) {
    toast = alert;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 4500), dismissToast);
  }

  // ---------- Alerts ----------
  void markSeen(String id) {
    alerts = [for (final a in alerts) a.id == id ? a.copyWith(seen: true) : a];
    _push((api) => api.markSeen(id));
    _commit();
  }

  void markAllSeen() {
    alerts = [for (final a in alerts) a.copyWith(seen: true)];
    _push((api) => api.markAllSeen());
    _commit();
  }

  void deleteAlert(String id) {
    alerts = alerts.where((a) => a.id != id).toList();
    _push((api) => api.deleteAlert(id));
    _commit();
  }

  void dismissToast() {
    toast = null;
    _toastTimer?.cancel();
    notifyListeners();
  }

  // ---------- Demo tools ----------
  /// Creates a ready-made alert so you can show the whole flow (banner, voice,
  /// history) on demand. [scenario]: 'known' | 'stranger' | 'vehicle'.
  /// With a server it goes through n8n; without one it is created on the phone.
  Future<String?> sendTestAlert(String scenario) async {
    final api = _api;
    final cam = cameras.where((c) => c.enabled).firstOrNull ?? cameras.firstOrNull;
    final camName = cam?.name ?? 'Front door';
    if (api == null) {
      final alert = _demoAlert(scenario, camName, cam?.image ?? Assets.frontDoor);
      alerts = [alert, ...alerts];
      _showToast(alert);
      _announce(alert);
      _commit();
      return null;
    }
    try {
      await api.testAlert(scenario, camName);
      if (syncing) await Future<void>.delayed(const Duration(milliseconds: 900));
      await refresh(); // shows the banner and speaks it right away
      return null;
    } on ApiException catch (e) {
      if (e.unauthorized) _expireSession();
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  /// Wipes the alert history (server + phone) for a clean start before presenting.
  Future<String?> clearAllAlerts() async {
    final api = _api;
    if (api != null) {
      try {
        await api.clearAlerts();
      } on ApiException catch (e) {
        if (e.unauthorized) _expireSession();
        return e.message;
      } catch (_) {
        return 'Could not reach the server. Check your connection.';
      }
    }
    alerts = [];
    toast = null;
    _toastTimer?.cancel();
    _speaker?.stop();
    _commit();
    return null;
  }

  AlertModel _demoAlert(String scenario, String camName, String camImage) {
    final spot = camName.toLowerCase();
    final now = DateTime.now();
    final id = 'a-${now.microsecondsSinceEpoch}';
    switch (scenario) {
      case 'vehicle':
        return AlertModel(
          id: id, cameraName: camName, image: Assets.night, kind: DetectionKind.vehicle,
          personName: 'Unknown', time: now, seen: false,
          summary: 'A white car has stopped near the $spot.',
          tags: const ['vehicle', 'white car'],
        );
      case 'stranger':
        return AlertModel(
          id: id, cameraName: camName, image: camImage, kind: DetectionKind.person,
          personName: 'Unknown', time: now, seen: false,
          summary: 'Someone in a blue jacket is at the $spot, holding a parcel. '
              'Nothing to worry about, but you may want to take a look.',
          tags: const ['person', 'blue jacket', 'parcel'],
        );
      default:
        final p = people.firstOrNull;
        final name = p?.name ?? 'Ada';
        final rel = (p?.relation.isNotEmpty ?? false) ? p!.relation : (p == null ? 'wife' : '');
        return AlertModel(
          id: id, cameraName: camName, image: camImage, kind: DetectionKind.person,
          personName: name, time: now, seen: false,
          relation: rel.isEmpty ? null : rel,
          summary: '${rel.isEmpty ? name : 'Your $rel, $name'}, is coming up to the $spot '
              'with shopping bags. You might want to get the door.',
          tags: const ['person', 'shopping bags'],
        );
    }
  }

  // ---------- Cameras ----------
  void toggleCamera(String id) {
    cameras = [
      for (final c in cameras) c.id == id ? c.copyWith(enabled: !c.enabled) : c
    ];
    _cameraListChanged();
  }

  void addCamera({
    required String name,
    required String location,
    required String image,
    String source = '',
  }) {
    cameras = [
      ...cameras,
      CameraModel(
        id: 'cam-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        location: location.isEmpty ? 'Not set' : location,
        image: image,
        enabled: true,
        source: source,
      ),
    ];
    _cameraListChanged();
  }

  /// Changes a camera's address / location and waits for the server to accept it.
  /// Returns an error message, or null on success.
  Future<String?> updateCamera(
    String id, {
    required String location,
    required String source,
  }) async {
    final before = cameras;
    cameras = [
      for (final c in cameras)
        c.id == id ? c.copyWith(location: location, source: source) : c
    ];
    _restartBackground();
    _commit();
    final api = _api;
    if (api == null) return null;
    try {
      await api.setCameras(List<CameraModel>.of(cameras));
      return null;
    } on ApiException catch (e) {
      if (e.unauthorized) _expireSession();
      cameras = before;
      _commit();
      return e.message;
    } catch (_) {
      cameras = before;
      _commit();
      return 'Could not reach the server. Check your connection and try again.';
    }
  }

  void removeCamera(String id) {
    cameras = cameras.where((c) => c.id != id).toList();
    _cameraListChanged();
  }

  void _cameraListChanged() {
    final snapshot = List<CameraModel>.of(cameras);
    _push((api) => api.setCameras(snapshot));
    _restartBackground();
    _commit();
  }

  // ---------- People (faces the camera should recognise) ----------
  /// Saves a person with 1-5 base64 JPEG photos. Returns an error message or null.
  /// edge.py picks the photos up from n8n within about a minute.
  Future<String?> addPerson({
    required String name,
    required String relation,
    required List<String> photos,
  }) async {
    final api = _api;
    if (api == null) {
      // Local demo mode: no server, just remember the person.
      people = [
        ...people,
        PersonModel(
          id: 'p-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          relation: relation,
          enrolled: true,
        ),
      ];
      _commit();
      return null;
    }
    try {
      await api.addPerson(name: name, relation: relation, photos: photos);
      people = await api.listPeople();
      _commit();
      return null;
    } on ApiException catch (e) {
      if (e.unauthorized) _expireSession();
      return e.message;
    } catch (_) {
      return 'Could not upload. Check your connection and try again.';
    }
  }

  void deletePerson(String id) {
    people = people.where((p) => p.id != id).toList();
    _push((api) => api.deletePerson(id));
    _commit();
  }

  // ---------- App lifecycle ----------
  // Polling while the app is in the background only burns data and n8n
  // executions (and cannot speak anyway). Pause it and catch up on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (user == null) return;
    if (state == AppLifecycleState.resumed) {
      _restartBackground();
      refresh();
    } else if (state == AppLifecycleState.paused) {
      _bgTimer?.cancel();
    }
  }

  // ---------- Background work ----------
  // Remote: poll the server. Local demo: simulate detections.
  void _restartBackground() {
    _bgTimer?.cancel();
    if (user == null) return;

    if (isRemote) {
      _bgTimer = Timer.periodic(Duration(seconds: kPollSeconds), (_) => refresh());
      return;
    }
    if (!cameras.any((c) => c.enabled)) return;
    _bgTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final active = cameras.where((c) => c.enabled).toList();
      if (active.isEmpty) return;
      final cam = active[_rng.nextInt(active.length)];
      const kinds = [
        DetectionKind.person,
        DetectionKind.person,
        DetectionKind.vehicle,
        DetectionKind.motion,
      ];
      final kind = kinds[_rng.nextInt(kinds.length)];
      final alert = AlertModel(
        id: 'a-${DateTime.now().microsecondsSinceEpoch}',
        cameraName: cam.name,
        image: cam.image,
        kind: kind,
        personName:
            kind == DetectionKind.person && _rng.nextBool() ? 'AKALUGWU' : 'Unknown',
        time: DateTime.now(),
        seen: false,
      );
      alerts = [alert, ...alerts];
      _showToast(alert);
      _announce(alert);
      _commit();
    });
  }

  // ---------- Seed data (local demo mode only) ----------
  static DateTime _todayAt(int h, int m) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day, h, m);
    if (d.isAfter(now)) d = d.subtract(const Duration(days: 1));
    return d;
  }

  static List<AlertModel> _seedAlerts() => [
        AlertModel(id: 'a1', cameraName: 'Front door', image: Assets.frontDoor, kind: DetectionKind.person, personName: 'AKALUGWU', time: _todayAt(1, 12), seen: false),
        AlertModel(id: 'a2', cameraName: 'Gate', image: Assets.gate, kind: DetectionKind.vehicle, personName: 'Unknown', time: _todayAt(0, 48), seen: true),
        AlertModel(id: 'a3', cameraName: 'Backyard', image: Assets.backyard, kind: DetectionKind.person, personName: 'AKALUGWU', time: _todayAt(23, 31), seen: true),
        AlertModel(id: 'a4', cameraName: 'Front door', image: Assets.night, kind: DetectionKind.motion, personName: 'Unknown', time: _todayAt(22, 17), seen: true),
      ]..sort((a, b) => b.time.compareTo(a.time));

  static List<CameraModel> _seedCameras() => const [
        CameraModel(id: 'cam-1', name: 'Front door', location: 'Front of house', image: Assets.frontDoor, enabled: true),
        CameraModel(id: 'cam-2', name: 'Gate', location: 'Driveway', image: Assets.gate, enabled: true),
        CameraModel(id: 'cam-3', name: 'Backyard', location: 'Back of house', image: Assets.backyard, enabled: false),
      ];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }
}
