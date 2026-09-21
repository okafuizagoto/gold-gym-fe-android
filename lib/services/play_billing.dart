import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'api_client.dart';

/// Hasil satu percobaan pembelian / pemulihan langganan lewat Google Play.
enum PlayOutcome {
  success,
  cancelled,
  pending,
  notAvailable,
  notConfigured,
  failed
}

class PlayResult {
  final PlayOutcome outcome;
  final String message;
  const PlayResult(this.outcome, [this.message = '']);
}

/// Langganan lewat Google Play Billing (hanya Android). Alur:
/// 1) minta account_id ke backend, dipakai sebagai obfuscatedAccountId saat membeli;
/// 2) beli lewat Play; 3) kirim purchase token ke backend (verifikasi + aktivasi + acknowledge);
/// 4) tutup pembelian di Play. Perpanjangan/pembatalan diurus backend lewat notifikasi Google (RTDN).
///
/// Padanan sisi server: Garrison-POS/goldgym internal/service/play.go.
class PlayBilling {
  PlayBilling._();
  static final PlayBilling instance = PlayBilling._();

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final _iap = InAppPurchase.instance;
  final _api = ApiClient();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Completer<PlayResult>? _pending;

  /// Pesan untuk kode error backend (sama dengan PLAN_MESSAGES di friendly_error.dart).
  static const _errorMessages = <String, String>{
    'PLAY_NOT_CONFIGURED':
        'Pembayaran langganan belum tersedia. Coba lagi nanti.',
    'PLAY_ACCOUNT_MISMATCH': 'Pembelian ini terikat ke akun lain.',
    'PLAY_TOKEN_IN_USE': 'Pembelian ini sudah dipakai oleh akun lain.',
    'PLAY_PAYMENT_PENDING':
        'Pembayaran masih diproses. Langganan aktif otomatis setelah selesai.',
    'PLAY_UNKNOWN_PRODUCT': 'Produk langganan tidak dikenali.',
  };

  void _ensureListening() {
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      _finish(PlayResult(PlayOutcome.failed, '$e'));
    });
  }

  void _finish(PlayResult r) {
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(r);
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _finish(const PlayResult(PlayOutcome.pending,
              'Pembayaran masih diproses. Langganan aktif otomatis setelah selesai.'));
          break;
        case PurchaseStatus.canceled:
          _finish(const PlayResult(PlayOutcome.cancelled));
          break;
        case PurchaseStatus.error:
          _finish(PlayResult(
              PlayOutcome.failed, p.error?.message ?? 'Pembelian gagal.'));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final res = await _verify(p);
          if (p.pendingCompletePurchase && res.outcome == PlayOutcome.success) {
            await _iap.completePurchase(p);
          }
          _finish(res);
          break;
      }
    }
  }

  /// Kirim purchase token ke backend. Backend idempotent -> aman diulang.
  Future<PlayResult> _verify(PurchaseDetails p) async {
    try {
      final res = await _api.post(
        '/gold-gym/v2/userdata/subscription/play/verify',
        {'purchase_token': p.verificationData.serverVerificationData},
      );
      if (res.statusCode == 200) {
        return const PlayResult(PlayOutcome.success, 'Langganan aktif.');
      }
      final body = jsonDecode(res.body);
      final code = body is Map ? '${body['error'] ?? ''}' : '';
      final msg =
          _errorMessages[code] ?? 'Gagal mengaktifkan langganan. Coba lagi.';
      return PlayResult(
          res.statusCode == 202 ? PlayOutcome.pending : PlayOutcome.failed,
          msg);
    } catch (_) {
      return const PlayResult(PlayOutcome.failed,
          'Tidak bisa menghubungi server. Pembelian Anda aman; coba pulihkan pembelian nanti.');
    }
  }

  /// account_id + status konfigurasi dari backend (null kalau gagal).
  Future<({bool enabled, String accountId})?> _account() async {
    try {
      final res =
          await _api.get('/gold-gym/v2/userdata/subscription/play/account');
      if (res.statusCode != 200) return null;
      final d = (jsonDecode(res.body) as Map)['data'] as Map;
      return (enabled: d['enabled'] == true, accountId: '${d['account_id']}');
    } catch (_) {
      return null;
    }
  }

  /// Beli paket [planId] (starter|growth|pro) dengan siklus bulanan/tahunan.
  Future<PlayResult> purchase(String planId, {required bool yearly}) async {
    if (!supported || !await _iap.isAvailable()) {
      return const PlayResult(PlayOutcome.notAvailable,
          'Google Play tidak tersedia di perangkat ini.');
    }
    final acc = await _account();
    if (acc == null || !acc.enabled) {
      return const PlayResult(PlayOutcome.notConfigured,
          'Pembelian langganan akan segera tersedia.');
    }
    final productId = 'okejual_$planId';
    final basePlan = yearly ? 'yearly' : 'monthly';
    final resp = await _iap.queryProductDetails({productId});
    GooglePlayProductDetails? chosen;
    for (final d in resp.productDetails.whereType<GooglePlayProductDetails>()) {
      final idx = d.subscriptionIndex;
      final offers = d.productDetails.subscriptionOfferDetails;
      if (idx == null || offers == null) continue;
      final o = offers[idx];
      if (o.basePlanId == basePlan && o.offerId == null) chosen = d;
    }
    if (chosen == null) {
      return const PlayResult(
          PlayOutcome.notAvailable, 'Paket ini belum tersedia di Google Play.');
    }
    _ensureListening();
    _pending = Completer<PlayResult>();
    final started = await _iap.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: chosen,
        applicationUserName: acc.accountId, // -> obfuscatedAccountId
        offerToken: chosen.offerToken,
      ),
    );
    if (!started) {
      _pending = null;
      return const PlayResult(
          PlayOutcome.failed, 'Tidak bisa membuka Google Play.');
    }
    return _pending!.future.timeout(const Duration(minutes: 10),
        onTimeout: () => const PlayResult(PlayOutcome.pending));
  }

  /// Pulihkan pembelian yang sudah ada (mis. ganti HP / instal ulang): token dikirim ke backend.
  Future<PlayResult> restore() async {
    if (!supported || !await _iap.isAvailable()) {
      return const PlayResult(PlayOutcome.notAvailable,
          'Google Play tidak tersedia di perangkat ini.');
    }
    final acc = await _account();
    if (acc == null || !acc.enabled) {
      return const PlayResult(PlayOutcome.notConfigured,
          'Pembelian langganan akan segera tersedia.');
    }
    _ensureListening();
    _pending = Completer<PlayResult>();
    await _iap.restorePurchases(applicationUserName: acc.accountId);
    return _pending!.future.timeout(const Duration(seconds: 15),
        onTimeout: () => const PlayResult(PlayOutcome.cancelled,
            'Tidak ada pembelian yang bisa dipulihkan.'));
  }
}
