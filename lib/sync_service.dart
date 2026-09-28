import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

    // Run one complete synchronization immediately, then repeat periodically.
    unawaited(syncNow());
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

  Future<int> syncNow() async {
    if (_running) return 0;

    if (!await _hasConnection()) {
      state.value = SyncState.offline;
      await refresh();
      // Do not bump revision while offline. Pages keep using their cached data
      // instead of repeatedly attempting a forced network refresh and showing
      // the same offline message every timer tick.
      return 0;
    }

    _running = true;
    try {
      state.value = SyncState.syncing;
      final count = await api.syncPending();
      final remoteRefreshSucceeded = await api.refreshRemoteData();
      await refresh();
      final remaining = await api.pendingCount();
      failed.value = LocalStore.failedCount;
      lastError.value = LocalStore.lastQueueError;
      state.value = remaining > 0
          ? (failed.value > 0 ? SyncState.error : SyncState.offline)
          : (remoteRefreshSucceeded ? SyncState.idle : SyncState.error);

      // Notify all screens that one GLOBAL synchronization completed. Each
      // screen then reloads its own cached data, while refreshRemoteData()
      // has already refreshed complaints, work orders, map and summary.
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
      // Do not continuously trigger page reloads when the network/server is
      // unavailable. The next successful synchronization will do so.
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
