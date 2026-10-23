import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'api_client.dart';

/// Play Integrity (anti APK modifikasi/Lucky Patcher, 2026-10-23). Aplikasi meminta nonce ke backend
/// (terikat akun), meminta token ke Google lewat MethodChannel `okejual/integrity` (lihat MainActivity.kt),
/// lalu backend men-decode token itu dan memutuskan apakah ini build asli dari Google Play.
///
/// Semua jalur di sini AMAN-GAGAL: kalau fitur mati di server, bukan Android, Google Play tidak ada, atau
/// terjadi error apa pun, [token] mengembalikan null dan aplikasi berjalan normal -- keputusan menolak
/// hanya ada di server (mode PLAY_INTEGRITY_MODE=enforce, hanya untuk pembelian langganan).
///
/// Padanan sisi server: gold-gym-be-v2 internal/service/subscription/integrity.go.
class PlayIntegrity {
  PlayIntegrity._();
  static final PlayIntegrity instance = PlayIntegrity._();

  static const _channel = MethodChannel('okejual/integrity');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final _api = ApiClient();
  bool _reported = false;

  /// Token integrity untuk akun yang sedang login, atau null (fitur mati / gagal).
  Future<String?> token() async {
    if (!supported) return null;
    try {
      final res = await _api.get('/gold-gym/v2/userdata/integrity/nonce');
      if (res.statusCode != 200) return null;
      final d = (jsonDecode(res.body) as Map)['data'] as Map;
      if (d['enabled'] != true) return null;
      final tok = await _channel.invokeMethod<String>('requestToken', {
        'nonce': '${d['nonce']}',
        if (d['cloud_project_number'] != null)
          'cloudProjectNumber': '${d['cloud_project_number']}',
      }).timeout(const Duration(seconds: 10));
      return (tok == null || tok.isEmpty) ? null : tok;
    } catch (_) {
      return null;
    }
  }

  /// Laporkan token sekali per sesi aplikasi (telemetri di log server; tidak pernah memblokir apa pun).
  Future<void> reportOncePerSession() async {
    if (_reported || !supported) return;
    _reported = true;
    final tok = await token();
    if (tok == null) return;
    try {
      await _api.post(
          '/gold-gym/v2/userdata/integrity/report', {'integrity_token': tok});
    } catch (_) {}
  }
}
