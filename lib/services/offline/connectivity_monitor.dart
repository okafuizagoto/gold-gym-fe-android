import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api_client.dart';

/// Status online/offline dari ping ke `/gold-gym/v2/ping` -- BUKAN dari status jaringan OS (Wi-Fi tersambung tapi tanpa
/// internet, atau server mati, tetap dianggap offline). Padanan utils/connectivity.ts di web.
/// Dua kegagalan berturut-turut baru dianggap offline (satu ping gagal bisa cuma gangguan sesaat).
class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor._();
  static final ConnectivityMonitor instance = ConnectivityMonitor._();

  static const _interval = Duration(seconds: 10);
  static const _timeout = Duration(seconds: 4);

  bool _online = true;
  int _failures = 0;
  Timer? _timer;

  bool get isOnline => _online;

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => checkNow());
    checkNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dipanggil juga saat sebuah request nyata gagal karena jaringan (lebih cepat tahu dari menunggu ping).
  void reportNetworkFailure() {
    _failures = 2;
    _set(false);
  }

  Future<bool> checkNow() async {
    try {
      final r = await http
          .get(Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/ping'))
          .timeout(_timeout);
      // server terjangkau = ada jawaban HTTP apa pun selain galat gerbang/server (5xx); 404 dari server lama
      // (sebelum route /ping ada) tetap berarti "online".
      if (r.statusCode < 500) {
        _failures = 0;
        _set(true);
        return true;
      }
      _failures++;
    } catch (_) {
      _failures++;
    }
    if (_failures >= 2) _set(false);
    return _online;
  }

  void _set(bool v) {
    if (v == _online) return;
    _online = v;
    notifyListeners();
  }
}
