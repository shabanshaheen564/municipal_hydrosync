import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

class LocalStore {
  static const cacheBoxName = 'hydrosync_cache';
  static const queueBoxName = 'hydrosync_queue';
  static const metaBoxName = 'hydrosync_meta';
  static late Box _cache;
  static late Box _queue;
  static late Box _meta;

  static Future<void> init() async {
    _cache = await Hive.openBox(cacheBoxName);
    _queue = await Hive.openBox(queueBoxName);
    _meta = await Hive.openBox(metaBoxName);
  }

  static String cacheKey(String user, String path, Map<String, String>? query) {
    final q =
        query == null || query.isEmpty
            ? ''
            : (query.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
                .map((e) => '${e.key}=${e.value}')
                .join('&');
    return '$user|$path|$q';
  }

  static Map<String, dynamic>? readCache(String key) {
    final raw = _cache.get(key);
    if (raw is! String) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map && value['data'] != null)
        return {'saved_at': value['saved_at'], 'data': value['data']};
    } catch (_) {}
    return null;
  }

  static Future<void> writeCache(String key, dynamic value) async {
    await _cache.put(
      key,
      jsonEncode({'saved_at': DateTime.now().toIso8601String(), 'data': value}),
    );
  }

  static Future<void> clearCache() async => _cache.clear();
  static Future<void> clearUserCache(String user) async {
    final keys = _cache.keys.where((k) => '$k'.startsWith('$user|')).toList();
    await _cache.deleteAll(keys);
  }

  static String enqueue(
    String method,
    String endpoint,
    Map<String, dynamic>? body, {
    int? localId,
  }) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_queue.length}';
    _queue.put(
      id,
      jsonEncode({
        'id': id,
        'method': method,
        'endpoint': endpoint,
        'body': body,
        'local_id': localId,
        'created_at': DateTime.now().toIso8601String(),
        'attempts': 0,
        'status': 'pending',
      }),
    );
    return id;
  }

  static List<Map<String, dynamic>> queueItems() {
    final result = <Map<String, dynamic>>[];
    for (final key in _queue.keys) {
      final raw = _queue.get(key);
      if (raw is String) {
        try {
          result.add(Map<String, dynamic>.from(jsonDecode(raw)));
        } catch (_) {}
      }
    }
    result.sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    return result;
  }

  static Future<void> removeQueueItem(String id) => _queue.delete(id);

  static Future<void> markQueueFailure(
    String id, {
    required int statusCode,
    required String message,
  }) async {
    final raw = _queue.get(id);
    if (raw is! String) return;
    try {
      final item = Map<String, dynamic>.from(jsonDecode(raw));
      final attempts = (item['attempts'] as num?)?.toInt() ?? 0;
      item['attempts'] = attempts + 1;
      item['status'] = 'failed';
      item['last_status_code'] = statusCode;
      item['last_error'] = message;
      item['last_attempt_at'] = DateTime.now().toIso8601String();
      await _queue.put(id, jsonEncode(item));
    } catch (_) {}
  }

  static int get pendingCount => _queue.length;
  static DateTime? get lastSyncAt {
    final raw = _meta.get('last_sync_at');
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  static Future<void> setLastSyncNow() async =>
      _meta.put('last_sync_at', DateTime.now().toIso8601String());

  static Future<void> patchEndpoint(
    String user,
    String endpoint,
    Map<String, dynamic> patch,
  ) async {
    for (final key in _cache.keys.toList()) {
      final keyString = '$key';
      if (!keyString.startsWith('$user|')) continue;
      final cached = readCache(keyString);
      if (cached == null) continue;
      final data = cached['data'];
      if (data is Map &&
          data['id'] != null &&
          endpoint.endsWith('/${data['id']}')) {
        await writeCache(keyString, {
          ...Map<String, dynamic>.from(data),
          ...patch,
        });
      } else if (data is Map && data['data'] is List) {
        final list =
            (data['data'] as List).map((item) {
              if (item is Map && endpoint.endsWith('/${item['id']}'))
                return {...Map<String, dynamic>.from(item), ...patch};
              return item;
            }).toList();
        await writeCache(keyString, {
          ...Map<String, dynamic>.from(data),
          'data': list,
        });
      } else if (data is List) {
        final list =
            data.map((item) {
              if (item is Map && endpoint.endsWith('/${item['id']}'))
                return {...Map<String, dynamic>.from(item), ...patch};
              return item;
            }).toList();
        await writeCache(keyString, list);
      }
    }
  }

  static Future<void> addPendingRecord(
    String user,
    String endpoint,
    Map<String, dynamic> body,
    String queueId,
  ) async {
    final localId = -DateTime.now().microsecondsSinceEpoch;
    final record = {
      ...body,
      'id': localId,
      'queued': true,
      'local_pending': true,
      'local_queue_id': queueId,
      'created_at': DateTime.now().toIso8601String(),
    };
    for (final key in _cache.keys.toList()) {
      final keyString = '$key';
      if (!keyString.startsWith('$user|$endpoint|')) continue;
      final cached = readCache(keyString);
      if (cached == null) continue;
      final data = cached['data'];
      if (data is Map && data['data'] is List) {
        await writeCache(keyString, {
          ...Map<String, dynamic>.from(data),
          'data': [record, ...(data['data'] as List)],
        });
      } else if (data is List)
        await writeCache(keyString, [record, ...data]);
    }
  }
}
