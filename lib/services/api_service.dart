import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://app.dttrack.com';
  static const String _hashKey = 'user_api_hash';
  static const String _emailKey = 'user_email';

  String? _apiHash;

  String? get apiHash => _apiHash;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiHash = prefs.getString(_hashKey);
  }

  Future<bool> isLoggedIn() async {
    await init();
    return _apiHash != null && _apiHash!.isNotEmpty;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = Uri.parse('$baseUrl/api/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'email': email,
        'password': password,
      },
    );

    final data = jsonDecode(response.body);
    if (data['status'] == 1 && data['user_api_hash'] != null) {
      _apiHash = data['user_api_hash'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hashKey, _apiHash!);
      await prefs.setString(_emailKey, email);
      return data;
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<void> logout() async {
    _apiHash = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.remove(_emailKey);
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final params = <String, String>{
      'user_api_hash': _apiHash ?? '',
      ...?query,
    };
    return Uri.parse('$baseUrl$path').replace(queryParameters: params);
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    if (_apiHash == null) await init();
    final response = await http.get(_buildUri(path, query));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('API Error ${response.statusCode}: ${response.body}');
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    if (_apiHash == null) await init();
    final uri = _buildUri(path);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body.map((k, v) => MapEntry(k, v.toString())),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('API Error ${response.statusCode}: ${response.body}');
  }

  // ========== DEVICES ==========
  Future<List<dynamic>> getDevices() async {
    final data = await _get('/api/get_devices');
    // Response is list of groups, each with items
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> getDevicesLatest() async {
    final data = await _get('/api/get_devices_latest');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  // ========== USER ==========
  Future<Map<String, dynamic>> getUserData() async {
    final data = await _get('/api/get_user_data');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  // ========== ALERTS / EVENTS ==========
  Future<Map<String, dynamic>> getAlerts() async {
    final data = await _get('/api/get_alerts');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> getEvents({int limit = 50}) async {
    final data = await _get('/api/get_events', {'limit': limit.toString()});
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  // ========== GEOFENCES ==========
  Future<Map<String, dynamic>> getGeofences() async {
    final data = await _get('/api/get_geofences');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  // ========== HISTORY ==========
  Future<Map<String, dynamic>> getHistory({
    required int deviceId,
    required String fromDate, // yyyy-MM-dd
    required String fromTime, // HH:mm:ss
    required String toDate,
    required String toTime,
  }) async {
    final data = await _get('/api/get_history', {
      'device_id': deviceId.toString(),
      'from_date': fromDate,
      'from_time': fromTime,
      'to_date': toDate,
      'to_time': toTime,
    });
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  // ========== COMMANDS ==========
  Future<Map<String, dynamic>> getSendCommandData() async {
    dynamic data;
    try {
      data = await _get('/api/send_command_data');
    } catch (_) {
      try {
        data = await _get('/api/get_command_data');
      } catch (_) {
        data = {};
      }
    }
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> sendCommand({
    required int deviceId,
    required String type, // gprs / sms
    String? message,
    int? templateId,
  }) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'type': type,
    };
    if (message != null) body['message'] = message;
    if (templateId != null) body['template_id'] = templateId;
    Map<String, dynamic> data = {};
    try {
      data = Map<String, dynamic>.from(await _post('/api/send_gprs_command', body));
    } catch (_) {
      try {
        data = Map<String, dynamic>.from(await _post('/api/send_command', body));
      } catch (e2) {
        // fallback: some installs use device_id + command
        final body2 = {
          'device_id': deviceId.toString(),
          'command': message ?? '',
          'type': type,
        };
        data = Map<String, dynamic>.from(await _post('/api/send_command', body2));
      }
    }
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> _sendCommandLegacy({
    required int deviceId,
    required String type,
    String? message,
    int? templateId,
  }) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'type': type,
    };
    if (message != null) body['message'] = message;
    if (templateId != null) body['template_id'] = templateId;
    final data = await _post('/api/send_command', body);
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  // ========== HELPERS ==========
  List<Map<String, dynamic>> flattenDevices(List<dynamic> groups) {
    final list = <Map<String, dynamic>>[];
    for (final g in groups) {
      if (g is Map && g['items'] is List) {
        for (final item in g['items']) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }
    return list;
  }
}
