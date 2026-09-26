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
    _subscription = Connectivity().onConnectivityChanged.listen((_) => syncNow());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => syncNow());
  }

  Future<void> refresh() async {
    pending.value = await api.pendingCount();
    lastSync.value = await api.lastSyncAt();
    failed.value = LocalStore.failedCount;
    lastError.value = LocalStore.lastQueueError;
  }

  Future<int> syncNow() async {
    if (_running) return 0;
    _running = true;
    try {
      state.value = SyncState.syncing;
      final count = await api.syncPending();
      await refresh();
      final remaining = await api.pendingCount();
      failed.value = LocalStore.failedCount;
      lastError.value = LocalStore.lastQueueError;
      state.value = remaining > 0
          ? (failed.value > 0 ? SyncState.error : SyncState.offline)
          : SyncState.idle;
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
      revision.value++;
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
    state.dispose(); pending.dispose(); lastSync.dispose(); failed.dispose(); lastError.dispose(); revision.dispose();
  }
}