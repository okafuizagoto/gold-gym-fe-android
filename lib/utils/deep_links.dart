import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/login_response_model.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../services/core_api.dart';
import 'login_session.dart';
import 'navigation.dart';
import 'toast.dart';

/// Tautan yang membuka aplikasi (Android App Links): tautan verifikasi di email
/// (`https://<domain>/user/verify/<kode>`) langsung membuka APLIKASI, bukan browser. Aplikasi memverifikasi email
/// lewat API yang sama dengan halaman web, menyimpan sesi (auto-login) lalu masuk ke layar tujuan --
/// padanan pages/user/verify/[code].tsx di web.
///
/// Syarat agar Android membuka aplikasi (bukan browser): intent-filter autoVerify di AndroidManifest dan berkas
/// `/.well-known/assetlinks.json` di domain yang memuat sidik jari sertifikat penanda tangan aplikasi.
/// Kalau tidak terpenuhi / aplikasi tidak terpasang, tautan tetap dibuka di web seperti biasa.
class DeepLinks {
  DeepLinks._();

  static StreamSubscription<Uri>? _sub;
  static final Set<String> _handled = {};
  static bool _busy = false;

  static Future<void> init() async {
    final links = AppLinks();
    try {
      final initial = await links.getInitialLink();
      if (initial != null) unawaited(_handle(initial));
    } catch (_) {}
    _sub ??= links.uriLinkStream.listen((u) => unawaited(_handle(u)), onError: (_) {});
  }

  /// Kode verifikasi dari `/user/verify/<kode>`; null kalau bukan tautan verifikasi.
  static String? verifyCodeOf(Uri uri) {
    final seg = uri.pathSegments;
    if (seg.length >= 3 && seg[0] == 'user' && seg[1] == 'verify') {
      return seg[2].isEmpty ? null : seg[2];
    }
    return null;
  }

  static Future<BuildContext?> _readyContext() async {
    for (var i = 0; i < 80; i++) {
      final c = navigatorKey.currentContext;
      if (c != null && navigatorKey.currentState != null) return c;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  static Future<void> _handle(Uri uri) async {
    final code = verifyCodeOf(uri);
    if (code == null) return;
    // tautan awal dan stream bisa mengirim URI yang sama dua kali; satu kode cukup diproses sekali
    if (_busy || !_handled.add(code)) return;
    _busy = true;
    try {
      final ctx = await _readyContext();
      if (ctx == null || !ctx.mounted) return;
      await _verify(ctx, code);
    } finally {
      _busy = false;
    }
  }

  static Future<void> _verify(BuildContext ctx, String code) async {
    final lang = ctx.read<LanguageProvider>();
    final nav = navigatorKey.currentState!;
    // dialog "memverifikasi" modal: layar di bawahnya tidak bisa disentuh selama proses
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(
                child: Text(lang.get('Verifying your email...',
                    'Memverifikasi email Anda...'))),
          ]),
        ),
      ),
    );
    int status = 0;
    String body = '';
    try {
      final res = await CoreApi().verifyEmail(code);
      status = res.statusCode;
      body = res.body;
    } catch (_) {
      status = -1;
    }
    // tutup dialog
    if (nav.mounted && nav.canPop()) nav.pop();

    final c = navigatorKey.currentContext;
    if (c == null || !c.mounted) return;
    if (status == 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final login = LoginResponseModel.fromJson(json);
      final email = (json['metadata']?['gold_email'] ?? login.username).toString();
      final dest = await LoginSession.save(login, email, lang: lang);
      if (!c.mounted) return;
      Provider.of<UserProvider>(c, listen: false)
          .setUserFromToken(login.bearerToken);
      nav.pushNamedAndRemoveUntil(dest, (r) => false);
      Toast.success(
          c,
          lang.get('Email verified! You are now signed in.',
              'Email berhasil diverifikasi! Anda sudah masuk.'));
    } else if (status == 400) {
      Toast.error(
          c,
          lang.get(
              'This verification link has expired or was already used. Sign in and request a new one.',
              'Tautan verifikasi sudah kedaluwarsa atau sudah dipakai. Masuk lalu minta tautan baru.'));
    } else {
      // kendala sistem/jaringan: pesan profesional, tanpa detail teknis
      Toast.error(
          c,
          lang.get(
              'Verification could not be processed right now. Please try again in a moment.',
              'Verifikasi belum dapat diproses. Silakan coba lagi beberapa saat lagi.'));
    }
  }
}
