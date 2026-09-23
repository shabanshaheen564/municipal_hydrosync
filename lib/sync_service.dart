import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api.dart';

enum SyncState { idle, syncing, offline, error }

class SyncService {
  final ApiClient api;
  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  final ValueNotifier<int> pending = ValueNotifier(0);
  final ValueNotifier<DateTime?> lastSync = ValueNotifier(null);
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _running = false;

  SyncService(this.api);

  Future<void> start() async {
    await refresh();
    _subscription = Connectivity().onConnectivityChanged.listen((_) => syncNow());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => syncNow());
  }

  Future<void> refresh() async {
    pending.value = await api.pendingCount();
    lastSync.value = await api.lastSyncAt();
  }

  Future<int> syncNow() async {
    if (_running) return 0;
    _running = true;
    try {
      state.value = SyncState.syncing;
      final count = await api.syncPending();
      await refresh();
      state.value = (await api.pendingCount()) > 0 ? SyncState.offline : SyncState.idle;
      return count;
    } catch (_) {
      await refresh();
      state.value = SyncState.error;
      return 0;
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    state.dispose(); pending.dispose(); lastSync.dispose();
  }
}