import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'local_store.dart';
import 'notification_service.dart';

enum SyncState { idle, syncing, offline, error }

class SyncService {
  final ApiClient api;
  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  final ValueNotifier<int> pending = ValueNotifier(0);
  final ValueNotifier<DateTime?> lastSync = ValueNotifier(null);
  final ValueNotifier<int> failed = ValueNotifier(0);
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  final ValueNotifier<int> revision = ValueNotifier(0);
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _running = false;

  SyncService(this.api);

  Future<void> start() async {
    await NotificationService.initialize();
    await refresh();

    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        unawaited(syncNow());
      } else {
        state.value = SyncState.offline;
      }
    });

    // One complete global synchronization immediately after login/startup.
    unawaited(syncNow());

    // Keep the local database fresh while online. Two minutes gives the field
    // app reasonably quick updates without hammering the API continuously.
    _timer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(syncNow()),
    );
  }

  Future<void> refresh() async {
    pending.value = await api.pendingCount();
    lastSync.value = await api.lastSyncAt();
    failed.value = LocalStore.failedCount;
    lastError.value = LocalStore.lastQueueError;
  }

  Future<bool> _hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<String?> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('auth_user');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['id'] != null) return '${decoded['id']}';
    } catch (_) {}
    return null;
  }

  Future<void> _cacheListPages(String endpoint) async {
    final userId = await _userId();
    if (userId == null) return;

    var page = 1;
    var total = 0;
    while (true) {
      final result = await api.list(
        endpoint,
        query: {'per_page': '100', 'page': '$page'},
        forceRefresh: true,
      );

      total = result.total;
      for (final item in result.items) {
        final id = item['id'];
        if (id == null) continue;
        await LocalStore.writeCache(
          LocalStore.cacheKey(userId, '$endpoint/$id', null),
          item,
        );
      }

      if (result.items.isEmpty || page * 100 >= total) break;
      page++;
    }
  }

  Future<int> syncNow() async {
    if (_running) return 0;

    if (!await _hasConnection()) {
      state.value = SyncState.offline;
      await refresh();
      // No revision while offline: pages keep using their cached data and do
      // not repeatedly force failed network requests/snackbars.
      return 0;
    }

    _running = true;
    try {
      state.value = SyncState.syncing;

      // First upload queued offline operations, then refresh the complete
      // remote operational snapshot (complaints, work orders, map, summary).
      final count = await api.syncPending();
      final remoteRefreshSucceeded = await api.refreshRemoteData();

      // Cache every complaint/work-order record under its detail endpoint so
      // tapping a record while offline opens the already downloaded data.
      await _cacheListPages('/complaints');
      await _cacheListPages('/work-orders');

      final sessionUser = await api.session();
      if (sessionUser?.permissions.contains('maintenance.view') == true) {
        await _cacheListPages('/maintenance/requests');

        final datasets = await api.list(
          '/maintenance/datasets',
          query: {'per_page': '100'},
          forceRefresh: true,
        );
        for (final dataset in datasets.items) {
          final datasetId = dataset['id'];
          if (datasetId == null) continue;
          await _cacheListPages('/maintenance/datasets/$datasetId/features');
        }
      }

      await refresh();
      final remaining = await api.pendingCount();
      failed.value = LocalStore.failedCount;
      lastError.value = LocalStore.lastQueueError;
      state.value = remaining > 0
          ? (failed.value > 0 ? SyncState.error : SyncState.offline)
          : (remoteRefreshSucceeded ? SyncState.idle : SyncState.error);

      // One revision means one GLOBAL synchronization. Every page listening
      // to this notifier reloads its own local cache together.
      revision.value++;

      if (count > 0) {
        await NotificationService.showSyncCompleted(count);
      }
      return count;
    } catch (_) {
      await refresh();
      state.value = SyncState.error;
      failed.value = LocalStore.failedCount;
      lastError.value = LocalStore.lastQueueError;
      // Do not trigger another page refresh when the remote synchronization
      // fails. The next successful synchronization will update all screens.
      return 0;
    } finally {
      _running = false;
    }
  }

  Future<int> retryFailed() async {
    final count = await LocalStore.retryFailed();
    await refresh();
    if (count > 0) await syncNow();
    return count;
  }

  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    state.dispose();
    pending.dispose();
    lastSync.dispose();
    failed.dispose();
    lastError.dispose();
    revision.dispose();
  }
}
