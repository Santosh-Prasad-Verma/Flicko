import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline }

class ConnectivityNotifier extends Notifier<NetworkStatus> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  NetworkStatus build() {
    _init();
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return NetworkStatus.online;
  }

  void _init() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      state = NetworkStatus.offline;
    } else {
      state = NetworkStatus.online;
    }
  }

  Future<void> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }
}

final connectivityProvider = NotifierProvider<ConnectivityNotifier, NetworkStatus>(() {
  return ConnectivityNotifier();
});
