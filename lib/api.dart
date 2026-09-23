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
  static const _cachePrefix = 'api_cache:';
  static const _lastSyncKey = 'last_sync_at';

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

  Future<String> _cacheKey(String path, Map<String, String>? query) async {
    final p = await _prefs;
    final user = p.getString(_userKey) ?? 'anonymous';
    final q = query == null || query.isEmpty
        ? ''
        : query.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$_cachePrefix$user:$path?$q';
  }

  Future<void> _cacheWrite(String key, dynamic value) async {
    final p = await _prefs;
    await p.setString(key, jsonEncode({
      'saved_at': DateTime.now().toIso8601String(),
      'data': value,
    }));
  }

  Future<dynamic> _cacheRead(String key) async {
    final raw = (await _prefs).getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded['data'] : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearOperationalCache() async {
    final p = await _prefs;
    final keys = p.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
    for (final key in keys) {
      await p.remove(key);
    }
  }

  Future<void> _queueAction(String method, String endpoint, Map<String, dynamic>? body) async {
    final p = await _prefs;
    final q = p.getStringList(_pendingKey) ?? [];
    q.add(jsonEncode({
      'id': DateTime.now().microsecondsSinceEpoch,
      'method': method,
      'endpoint': endpoint,
      'body': body,
    }));
    await p.setStringList(_pendingKey, q);
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

  Future<void> clearLocalCache() async => _clearOperationalCache();

  Future<void> logout() async {
    try {
      await _send('POST', '/logout');
    } catch (_) {}
    final p = await _prefs;
    await p.remove(_tokenKey);
    await p.remove(_userKey);
    await _clearOperationalCache();
  }

  Future<bool> isLoggedIn() async => (await _prefs).getString(_tokenKey) != null;

  Future<SessionUser?> session() async {
    final raw = (await _prefs).getString(_userKey);
    return raw == null ? null : SessionUser.fromJson(jsonDecode(raw));
  }

  Future<Map<String, dynamic>> summary() async {
    final key = await _cacheKey('/reports/summary', null);
    try {
      final d = await _send('GET', '/reports/summary');
      await _cacheWrite(key, d);
      return Map<String, dynamic>.from(d);
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      final cached = await _cacheRead(key);
      if (cached is Map) return Map<String, dynamic>.from(cached);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> operationalMap() async {
    final key = await _cacheKey('/map/operational', null);
    try {
      final d = await _send('GET', '/map/operational');
      await _cacheWrite(key, d);
      return Map<String, dynamic>.from(d);
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      final cached = await _cacheRead(key);
      if (cached is Map) return Map<String, dynamic>.from(cached);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _pendingCreates(String endpoint) async {
    final p = await _prefs;
    final q = p.getStringList(_pendingKey) ?? [];
    final result = <Map<String, dynamic>>[];
    for (final raw in q) {
      try {
        final a = Map<String, dynamic>.from(jsonDecode(raw));
        if (a['method'] == 'POST' && a['endpoint'] == endpoint && a['body'] is Map) {
          final body = Map<String, dynamic>.from(a['body']);
          result.add({
            ...body,
            'id': -(a['id'] as num).toInt(),
            'queued': true,
            'local_pending': true,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (_) {}
    }
    return result.reversed.toList();
  }

  Future<ApiList> list(String endpoint, {Map<String, String>? query}) async {
    final key = await _cacheKey(endpoint, query);
    dynamic d;
    try {
      d = await _send('GET', endpoint, query: query);
      await _cacheWrite(key, d);
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      d = await _cacheRead(key);
      if (d == null) rethrow;
    }
    final raw = d is List
        ? d
        : d is Map && d['data'] is List
            ? d['data']
            : d is Map && d['items'] is List
                ? d['items']
                : <dynamic>[];
    final items = (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
    final pending = await _pendingCreates(endpoint);
    if (pending.isNotEmpty) items.insertAll(0, pending);
    final total = d is Map && d['meta'] is Map && d['meta']['total'] is num
        ? (d['meta']['total'] as num).toInt()
        : items.length;
    return ApiList(items, total);
  }

  Future<Map<String, dynamic>> getOne(String endpoint) async {
    final key = await _cacheKey(endpoint, null);
    try {
      final d = await _send('GET', endpoint);
      await _cacheWrite(key, d);
      return Map<String, dynamic>.from(d);
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      final cached = await _cacheRead(key);
      if (cached is Map) return Map<String, dynamic>.from(cached);
      rethrow;
    }
  }

  Future<ApiList> users() async => list('/users', query: {'per_page': '100'});

  Future<Map<String, dynamic>> create(String endpoint, Map<String, dynamic> body) async {
    try {
      final result = Map<String, dynamic>.from(await _send('POST', endpoint, body: body));
      await _clearOperationalCache();
      return result;
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      await _queueAction('POST', endpoint, body);
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> update(String endpoint, Map<String, dynamic> body) async {
    try {
      final result = Map<String, dynamic>.from(await _send('PUT', endpoint, body: body));
      await _clearOperationalCache();
      return result;
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      await _queueAction('PUT', endpoint, body);
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> convertComplaint(
    int complaintId, {
    required String title,
    required String description,
    required String priority,
    required int assignedTo,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'priority': priority,
      'assigned_to': assignedTo,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    try {
      final result = Map<String, dynamic>.from(await _send('POST', '/complaints/$complaintId/convert-to-work-order', body: body));
      await _clearOperationalCache();
      return result;
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      await _queueAction('POST', '/complaints/$complaintId/convert-to-work-order', body);
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> addComplaintToWorkOrder(int complaintId, int workOrderId) async {
    final body = {'work_order_id': workOrderId};
    try {
      final result = Map<String, dynamic>.from(await _send('POST', '/complaints/$complaintId/add-to-work-order', body: body));
      await _clearOperationalCache();
      return result;
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      await _queueAction('POST', '/complaints/$complaintId/add-to-work-order', body);
      return {'queued': true};
    }
  }

  Future<int> pendingCount() async => (await _prefs).getStringList(_pendingKey)?.length ?? 0;

  Future<DateTime?> lastSyncAt() async {
    final raw = (await _prefs).getString(_lastSyncKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<int> syncPending() async {
    final p = await _prefs;
    final old = p.getStringList(_pendingKey) ?? [];
    if (old.isEmpty) return 0;
    final keep = <String>[];
    var done = 0;
    for (final raw in old) {
      final a = jsonDecode(raw);
      try {
        await _send(a['method'], a['endpoint'], body: a['body'] == null ? null : a['body']);
        done++;
      } on ApiException catch (e) {
        keep.add(raw);
        if (e.status == 0) break;
      } catch (_) {
        keep.add(raw);
      }
    }
    for (var i = done + keep.length; i < old.length; i++) {
      keep.add(old[i]);
    }
    await p.setStringList(_pendingKey, keep);
    if (done > 0) {
      await _clearOperationalCache();
      await p.setString(_lastSyncKey, DateTime.now().toIso8601String());
    }
    return done;
  }
}
