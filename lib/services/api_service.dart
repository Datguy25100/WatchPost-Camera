import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get unauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin client for the n8n "WatchPost API" webhook (one URL, action-routed).
class ApiService {
  ApiService(this.baseUrl);

  final String baseUrl;
  String? token;

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> body = const {},
    Duration timeout = const Duration(seconds: 12),
  ]) async {
    final res = await http
        .post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'x-token': token!,
          },
          body: jsonEncode({'action': action, ...body}),
        )
        .timeout(timeout);

    if (res.statusCode == 404) {
      // n8n answers 404 when the workflow is not published or the URL is the
      // "test" URL / has a typo.
      throw ApiException(
        'Server not found (404). Is the n8n workflow published, and is the URL the Production URL?',
        statusCode: 404,
      );
    }

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode >= 400 || data['error'] != null) {
      throw ApiException(
        data['error']?.toString() ?? 'Server error (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return data;
  }

  Future<String> login(String email, String password) async {
    final data = await _call('login', {'email': email, 'password': password});
    return data['token'] as String;
  }

  /// People the server is still deleting are hidden so they do not flicker
  /// back into the list between the delete tap and edge.py's confirmation.
  static List<PersonModel> _people(Object? raw) => (raw as List? ?? const [])
      .map((e) => PersonModel.fromJson(e as Map<String, dynamic>))
      .where((p) => !p.deleting)
      .toList();

  /// [have] = ids of alerts whose snapshot the app already holds, so the server
  /// does not send those (large) images again on every poll.
  Future<({List<AlertModel> alerts, List<CameraModel> cameras, List<PersonModel> people})>
      getState({List<String> have = const []}) async {
    final data = await _call('getState', {'have': have});
    return (
      people: _people(data['people']),
      alerts: (data['alerts'] as List)
          .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      cameras: (data['cameras'] as List)
          .map((e) => CameraModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Demo tools: the server creates a canned alert ('known' | 'stranger' | 'vehicle').
  Future<void> testAlert(String scenario, String camera) =>
      _call('testAlert', {'scenario': scenario, 'camera': camera});
  Future<void> clearAlerts() => _call('clearAlerts');

  Future<void> markSeen(String id) => _call('markSeen', {'id': id});
  Future<void> markAllSeen() => _call('markAllSeen');
  Future<void> deleteAlert(String id) => _call('deleteAlert', {'id': id});
  Future<void> logout() => _call('logout');

  Future<List<PersonModel>> listPeople() async =>
      _people((await _call('listPeople'))['people']);

  /// [photos] are raw base64 JPEGs (no data: prefix), 1-5 of them, ~150 KB max each.
  Future<void> addPerson({
    required String name,
    required String relation,
    required List<String> photos,
  }) =>
      _call(
        'addPerson',
        {'name': name, 'relation': relation, 'photos': photos},
        const Duration(seconds: 60),
      );

  Future<void> deletePerson(String id) => _call('deletePerson', {'id': id});

  Future<void> setCameras(List<CameraModel> cameras) =>
      _call('setCameras', {'cameras': cameras.map((c) => c.toJson()).toList()});
}
