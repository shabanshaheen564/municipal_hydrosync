import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  const ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _pendingKey = 'pending_actions';

  final String baseUrl;
  ApiClient({this.baseUrl = AppConfig.apiBaseUrl});

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<Map<String, String>> _headers() async {
    final p = await _prefs;
    final t = p.getString(_tokenKey);
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final h = await _headers();
    late http.Response r;
    try {
      switch (method) {
        case 'GET':
          r = await http.get(uri, headers: h).timeout(AppConfig.requestTimeout);
          break;
        case 'POST':
          r = await http.post(uri, headers: h, body: body == null ? null : jsonEncode(body)).timeout(AppConfig.requestTimeout);
          break;
        case 'PUT':
          r = await http.put(uri, headers: h, body: body == null ? null : jsonEncode(body)).timeout(AppConfig.requestTimeout);
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: h).timeout(AppConfig.requestTimeout);
          break;
        default:
          throw const ApiException(0, 'طريقة طلب غير مدعومة.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(0, 'تعذر الاتصال بالخادم. تحقق من الإنترنت أو عنوان API.');
    }

    dynamic d;
    try {
      d = jsonDecode(r.body);
    } catch (_) {
      d = r.body;
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final message = d is Map
          ? '${d['message'] ?? d['error'] ?? 'حدث خطأ في الخادم'}'
          : 'حدث خطأ في الخادم';
      throw ApiException(r.statusCode, message);
    }
    return d;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final d = Map<String, dynamic>.from(await _send('POST', '/login', body: {
      'email': email,
      'password': password,
    }));
    final p = await _prefs;
    await p.setString(_tokenKey, '${d['token']}');
    await p.setString(_userKey, jsonEncode(d['user']));
    return d;
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/logout');
    } catch (_) {}
    final p = await _prefs;
    await p.remove(_tokenKey);
    await p.remove(_userKey);
  }

  Future<bool> isLoggedIn() async => (await _prefs).getString(_tokenKey) != null;

  Future<SessionUser?> session() async {
    final raw = (await _prefs).getString(_userKey);
    return raw == null ? null : SessionUser.fromJson(jsonDecode(raw));
  }

  Future<Map<String, dynamic>> summary() async => Map<String, dynamic>.from(await _send('GET', '/reports/summary'));

  Future<Map<String, dynamic>> operationalMap() async => Map<String, dynamic>.from(await _send('GET', '/map/operational'));

  Future<ApiList> list(String endpoint, {Map<String, String>? query}) async {
    final d = await _send('GET', endpoint, query: query);
    final raw = d is List
        ? d
        : d is Map && d['data'] is List
            ? d['data']
            : d is Map && d['items'] is List
                ? d['items']
                : <dynamic>[];
    final items = (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
    final total = d is Map && d['meta'] is Map && d['meta']['total'] is num
        ? (d['meta']['total'] as num).toInt()
        : items.length;
    return ApiList(items, total);
  }

  Future<Map<String, dynamic>> getOne(String endpoint) async => Map<String, dynamic>.from(await _send('GET', endpoint));

  Future<ApiList> users() async => list('/users', query: {'per_page': '100'});

  Future<Map<String, dynamic>> create(String endpoint, Map<String, dynamic> body) async {
    try {
      return Map<String, dynamic>.from(await _send('POST', endpoint, body: body));
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      final p = await _prefs;
      final q = p.getStringList(_pendingKey) ?? [];
      q.add(jsonEncode({'method': 'POST', 'endpoint': endpoint, 'body': body}));
      await p.setStringList(_pendingKey, q);
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> update(String endpoint, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _send('PUT', endpoint, body: body));

  Future<Map<String, dynamic>> convertComplaint(
    int complaintId, {
    required String title,
    required String description,
    required String priority,
    required int assignedTo,
    String? notes,
  }) async => Map<String, dynamic>.from(await _send('POST', '/complaints/$complaintId/convert-to-work-order', body: {
        'title': title,
        'description': description,
        'priority': priority,
        'assigned_to': assignedTo,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      }));

  Future<Map<String, dynamic>> addComplaintToWorkOrder(int complaintId, int workOrderId) async =>
      Map<String, dynamic>.from(await _send('POST', '/complaints/$complaintId/add-to-work-order', body: {
        'work_order_id': workOrderId,
      }));

  Future<int> pendingCount() async => (await _prefs).getStringList(_pendingKey)?.length ?? 0;

  Future<int> syncPending() async {
    final p = await _prefs;
    final old = p.getStringList(_pendingKey) ?? [];
    final keep = <String>[];
    var done = 0;
    for (final raw in old) {
      final a = jsonDecode(raw);
      try {
        await _send(a['method'], a['endpoint'], body: a['body']);
        done++;
      } catch (_) {
        keep.add(raw);
      }
    }
    await p.setStringList(_pendingKey, keep);
    return done;
  }
}
