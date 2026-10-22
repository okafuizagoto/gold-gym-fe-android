import 'dart:convert';
import 'api_client.dart';

/// Panduan tooltip pertama kali per role (2026-10-22). Padanan
/// gold-gym-fe-next-js-ts services/onboarding.ts -- backend
/// internal/delivery/http/onboarding.
class OnboardingApi {
  static const _base = '/gold-gym/v2/onboarding';

  /// true kalau role ini sudah pernah menandai panduan sebagai "sudah dilihat".
  /// Gagal cek -> dianggap sudah (jangan paksa tour tampil kalau API bermasalah).
  Future<bool> isSeen(String role) async {
    try {
      final resp =
          await ApiClient().get(_base, queryParams: {'role': role});
      if (resp.statusCode != 200) return true;
      return jsonDecode(resp.body)['data']?['seen'] == true;
    } catch (_) {
      return true;
    }
  }

  /// Tandai role ini sudah dilihat (idempoten). Gagal simpan tidak fatal.
  Future<void> markSeen(String role) async {
    try {
      await ApiClient().post(_base, {'role': role});
    } catch (_) {}
  }
}
