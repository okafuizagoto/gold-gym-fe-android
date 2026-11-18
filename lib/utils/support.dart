import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../models/manual_pay_model.dart';
import '../services/manual_pay_api.dart';
import 'constants.dart';
import 'storage.dart';

/// Bantuan WhatsApp (2026-11-18, putaran 4 founder): satu ketukan membuka WA ke nomor dukungan dengan data diagnosa
/// yang dibutuhkan SOP bantuan (akun, outlet, versi, waktu, nota tertunda/gagal, galat terakhir). Tidak memuat data
/// pembeli. Nomor diatur admin (Kontak & Pembayaran); kosong = tombol disembunyikan.
/// Padanan web: utils/support.ts -- ubah keduanya bersamaan.
class Support {
  static SupportContact? _cached;
  static Future<SupportContact?>? _inflight;
  static String _lastError = '';

  /// Dipanggil Toast.error: pesan galat terakhir ikut dikirim di pesan bantuan.
  static void rememberLastError(String msg) {
    _lastError = msg.length > 160 ? msg.substring(0, 160) : msg;
  }

  static SupportContact? get cached => _cached;

  /// Hanya untuk tes.
  static void setCachedForTest(SupportContact? c) => _cached = c;

  static Future<SupportContact?> load({bool force = false}) {
    if (_cached != null && !force) return Future.value(_cached);
    return _inflight ??= () async {
      try {
        final r = await ManualPayApi().contact();
        if (r.statusCode == 200) {
          final d = (jsonDecode(r.body) as Map)['data'];
          if (d is Map) _cached = SupportContact.fromJson(d.cast<String, dynamic>());
        }
      } catch (_) {
        // tanpa jaringan: tombol tetap tersembunyi
      }
      _inflight = null;
      return _cached;
    }();
  }

  static Future<String> message({String topic = '', int pending = 0, int failed = 0, String extra = ''}) async {
    final lines = <String>['Halo Okejual, saya butuh bantuan${topic.isNotEmpty ? ': $topic' : '.'}'];
    final email = await Storage.get(AppConstants.userEmail) ?? '';
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (email.isNotEmpty) lines.add('Akun: $email');
    if (outcode.isNotEmpty) lines.add('Outlet: $outcode');
    lines.add('Aplikasi: Android ${AppConstants.version}');
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    String two(int v) => v.toString().padLeft(2, '0');
    lines.add('Waktu: ${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}.${two(now.minute)} WIB');
    if (pending > 0 || failed > 0) lines.add('Nota menunggu kirim: $pending, gagal: $failed');
    if (_lastError.isNotEmpty) lines.add('Galat terakhir: $_lastError');
    if (extra.isNotEmpty) lines.add(extra);
    return lines.join('\n');
  }

  static Uri whatsappUri(String number, String text) =>
      Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}');

  static Future<void> open(String number, String text) =>
      launchUrl(whatsappUri(number, text), mode: LaunchMode.externalApplication);
}
