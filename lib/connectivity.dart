import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final _isOnline = ValueNotifier<bool>(true);
  late final Connectivity _connectivity;

  ValueNotifier<bool> get isOnline => _isOnline;

  Future<void> init() async {
    _connectivity = Connectivity();

    // Check initial state
    final result = await _connectivity.checkConnectivity();
    _isOnline.value = result.contains(ConnectivityResult.none) == false;

    // Listen to changes
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline.value = result.contains(ConnectivityResult.none) == false;
    });
  }

  void dispose() {
    _isOnline.dispose();
  }
}
