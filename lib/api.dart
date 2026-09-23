import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'models.dart';
import 'local_store.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  const ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const _tokenKey = 'auth_token';

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hex.substring(0, 8) + '-' +
        hex.substring(8, 12) + '-' +
        hex.substring(12, 16) + '-' +
        hex.substring(16, 20) + '-' +
        hex.substring(20);
  }
  static const _userKey = 'auth_user';
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

  Future<String> _userCacheId() async {
    final raw = (await _prefs).getString(_userKey);
    if (raw == null) return 'anonymous';
    try {
      return '${jsonDecode(raw)['id'] ?? 'anonymous'}';
    } catch (_) {
      return 'anonymous';
    }
  }

  Future<String> _cacheKey(String path, Map<String, String>? query) async =>
      LocalStore.cacheKey(await _userCacheId(), path, query);

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
          r = await http
              .post(
                uri,
                headers: h,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(AppConfig.requestTimeout);
          break;
        case 'PUT':
          r = await http
              .put(
                uri,
                headers: h,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(AppConfig.requestTimeout);
          break;
        case 'DELETE':
          r = await http
              .delete(uri, headers: h)
              .timeout(AppConfig.requestTimeout);
          break;
        default:
          throw const ApiException(0, 'طريقة طلب غير مدعومة.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(
        0,
        'تعذر الاتصال بالخادم. تحقق من الإنترنت أو عنوان API.',
      );
    }
    dynamic d;
    try {
      d = jsonDecode(r.body);
    } catch (_) {
      d = r.body;
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final message =
          d is Map
              ? '${d['message'] ?? d['error'] ?? 'حدث خطأ في الخادم'}'
              : 'حدث خطأ في الخادم';
      throw ApiException(r.statusCode, message);
    }
    return d;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final d = Map<String, dynamic>.from(
      await _send(
        'POST',
        '/login',
        body: {'email': email, 'password': password},
      ),
    );
    final p = await _prefs;
    await p.setString(_tokenKey, '${d['token']}');
    await p.setString(_userKey, jsonEncode(d['user']));
    return d;
  }

  Future<void> clearLocalCache() async =>
      LocalStore.clearUserCache(await _userCacheId());
  Future<void> logout() async {
    try {
      await _send('POST', '/logout');
    } catch (_) {}
    final p = await _prefs;
    await p.remove(_tokenKey);
    await p.remove(_userKey);
    await LocalStore.clearCache();
  }

  Future<bool> isLoggedIn() async =>
      (await _prefs).getString(_tokenKey) != null;
  Future<SessionUser?> session() async {
    final raw = (await _prefs).getString(_userKey);
    return raw == null ? null : SessionUser.fromJson(jsonDecode(raw));
  }

  Future<Map<String, dynamic>> _cachedMap(
    String path,
    Map<String, String>? query,
  ) async {
    final c = LocalStore.readCache(await _cacheKey(path, query));
    if (c?['data'] is Map) return Map<String, dynamic>.from(c!['data']);
    throw const ApiException(0, 'لا توجد بيانات محلية محفوظة بعد.');
  }

  Future<Map<String, dynamic>> _readMap(
    String path, {
    Map<String, String>? query,
  }) async {
    final key = await _cacheKey(path, query);
    final cached = LocalStore.readCache(key);
    if (cached?['data'] is Map) {
      _refreshMap(key, path, query);
      return Map<String, dynamic>.from(cached!['data']);
    }
    try {
      final d = await _send('GET', path, query: query);
      await LocalStore.writeCache(key, d);
      return Map<String, dynamic>.from(d);
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      return _cachedMap(path, query);
    }
  }

  Future<void> _refreshMap(
    String key,
    String path,
    Map<String, String>? query,
  ) async {
    try {
      final d = await _send('GET', path, query: query);
      await LocalStore.writeCache(key, d);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> summary() => _readMap('/reports/summary');
  Future<Map<String, dynamic>> operationalMap() => _readMap('/map/operational');

  Future<List<Map<String, dynamic>>> _pendingCreates(String endpoint) async {
    final result = <Map<String, dynamic>>[];
    for (final a in LocalStore.queueItems()) {
      if (a['method'] == 'POST' &&
          a['endpoint'] == endpoint &&
          a['body'] is Map) {
        result.add({
          ...Map<String, dynamic>.from(a['body']),
          'id': (a['local_id'] as num?)?.toInt() ?? -(a['id'].hashCode.abs() + 1),
          'queued': true,
          'local_pending': true,
          'local_queue_id': a['id'],
        });
      }
    }
    return result.reversed.toList();
  }

  Future<ApiList> list(String endpoint, {Map<String, String>? query}) async {
    final key = await _cacheKey(endpoint, query);
    dynamic d;
    final cached = LocalStore.readCache(key);
    if (cached != null) {
      d = cached['data'];
      // Background refresh without blocking UI
      _refreshList(key, endpoint, query);
    } else {
      try {
        d = await _send('GET', endpoint, query: query);
        await LocalStore.writeCache(key, d);
      } on ApiException catch (e) {
        if (e.status != 0) rethrow;
        throw const ApiException(
          0,
          'لا توجد بيانات محلية. افتح التطبيق مرة واحدة مع الإنترنت لمزامنة البيانات.',
        );
      }
    }
    final raw =
        d is List
            ? d
            : d is Map && d['data'] is List
            ? d['data']
            : d is Map && d['items'] is List
            ? d['items']
            : <dynamic>[];
    final items =
        (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
    final pending = await _pendingCreates(endpoint);
    if (pending.isNotEmpty) {
      final existingQueueIds =
          items
              .map((item) => item['local_queue_id']?.toString())
              .whereType<String>()
              .toSet();
      items.insertAll(
        0,
        pending.where(
          (item) => !existingQueueIds.contains(
            item['local_queue_id']?.toString(),
          ),
        ),
      );
    }
    final total =
        d is Map && d['meta'] is Map && d['meta']['total'] is num
            ? (d['meta']['total'] as num).toInt()
            : items.length;
    return ApiList(items, total);
  }

  Future<void> _refreshList(
    String key,
    String endpoint,
    Map<String, String>? query,
  ) async {
    try {
      final d = await _send('GET', endpoint, query: query);
      await LocalStore.writeCache(key, d);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getOne(String endpoint) async {
    final key = await _cacheKey(endpoint, null);
    final cached = LocalStore.readCache(key);
    if (cached != null) {
      _refreshOne(key, endpoint);
      return Map<String, dynamic>.from(cached['data']);
    }
    try {
      final d = await _send('GET', endpoint);
      await LocalStore.writeCache(key, d);
      return Map<String, dynamic>.from(d);
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      throw const ApiException(0, 'لا توجد نسخة محلية من هذه البيانات.');
    }
  }

  Future<void> _refreshOne(String key, String endpoint) async {
    try {
      final d = await _send('GET', endpoint);
      await LocalStore.writeCache(key, d);
    } catch (_) {}
  }

  Future<ApiList> users() async => list('/users', query: {'per_page': '100'});

  Future<Map<String, dynamic>> create(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final payload = {
      ...body,
      'idempotency_key': body['idempotency_key'] ?? _newIdempotencyKey(),
    };

    try {
      final result = Map<String, dynamic>.from(
        await _send('POST', endpoint, body: payload),
      );
      await LocalStore.clearCache();
      return result;
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      final user = await _userCacheId();
      final localId = -DateTime.now().microsecondsSinceEpoch;
      final qid = LocalStore.enqueue('POST', endpoint, payload, localId: localId);
      await LocalStore.addPendingRecord(
        user,
        endpoint,
        payload,
        qid,
        localId: localId,
      );
      return {
        'queued': true,
        'local_queue_id': qid,
        'local_id': localId,
      };
    }
  }

  Future<Map<String, dynamic>> update(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final result = Map<String, dynamic>.from(
        await _send('PUT', endpoint, body: body),
      );
      await LocalStore.clearCache();
      return result;
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      final user = await _userCacheId();
      final qid = LocalStore.enqueue('PUT', endpoint, body);
      await LocalStore.patchEndpoint(user, endpoint, {
        ...body,
        'queued': true,
        'local_pending': true,
        'local_queue_id': qid,
      });
      return {'queued': true, 'local_queue_id': qid};
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
      final r = Map<String, dynamic>.from(
        await _send(
          'POST',
          '/complaints/$complaintId/convert-to-work-order',
          body: body,
        ),
      );
      await LocalStore.clearCache();
      return r;
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      final qid = LocalStore.enqueue(
        'POST',
        '/complaints/$complaintId/convert-to-work-order',
        body,
      );
      return {'queued': true, 'local_queue_id': qid};
    }
  }

  Future<Map<String, dynamic>> addComplaintToWorkOrder(
    int complaintId,
    int workOrderId,
  ) async {
    final body = {'work_order_id': workOrderId};
    try {
      final r = Map<String, dynamic>.from(
        await _send(
          'POST',
          '/complaints/$complaintId/add-to-work-order',
          body: body,
        ),
      );
      await LocalStore.clearCache();
      return r;
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      final qid = LocalStore.enqueue(
        'POST',
        '/complaints/$complaintId/add-to-work-order',
        body,
      );
      return {'queued': true, 'local_queue_id': qid};
    }
  }

  Future<int> pendingCount() async => LocalStore.pendingCount;
  Future<DateTime?> lastSyncAt() async => LocalStore.lastSyncAt;

  Future<int> syncPending() async {
    final items = LocalStore.queueItems();
    if (items.isEmpty) return 0;
    var done = 0;

    for (final a in items) {
      try {
        await _send('${a['method']}', '${a['endpoint']}', body: a['body']);
        await LocalStore.removeQueueItem('${a['id']}');
        done++;
      } on ApiException catch (e) {
        // Network failure: keep the item for a later retry.
        if (e.status == 0) break;

        // Server-side validation/auth/conflict failures must never be
        // silently deleted. Preserve the action and record the reason.
        await LocalStore.markQueueFailure(
          '${a['id']}',
          statusCode: e.status,
          message: e.message,
        );

        // A failed action should not block unrelated queued actions.
        continue;
      } catch (_) {
        // Unknown/network error: keep the item and retry later.
        break;
      }
    }

    if (done > 0) {
      await LocalStore.clearCache();
      await LocalStore.setLastSyncNow();
    }

    return done;
  }
}
