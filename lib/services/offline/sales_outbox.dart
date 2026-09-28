import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../utils/constants.dart';
import '../../utils/storage.dart';
import '../sales_api.dart';
import 'connectivity_monitor.dart';
import 'offline_store.dart';

/// UUID v4 (kunci idempotensi nota: dibuat SEKALI di perangkat, dipakai ulang di setiap percobaan kirim,
/// sehingga retry tidak pernah menggandakan transaksi -- server mengenali sale_id yang sama).
String newSaleId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

enum OutboxStatus { pending, failed }

class OutboxSale {
  final String saleId;
  final String userKey; // gold_id akun yang membuat nota (nota hanya dikirim oleh akun yang sama)
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int attempts;
  OutboxStatus status;
  String? error;

  OutboxSale({
    required this.saleId,
    required this.userKey,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.status = OutboxStatus.pending,
    this.error,
  });

  Map<String, dynamic> get header =>
      (payload['data']?['header'] as Map?)?.cast<String, dynamic>() ?? {};
  String get outcode => '${header['sale_outcode'] ?? ''}';
  num get total => num.tryParse('${header['sale_transtotal'] ?? 0}') ?? 0;
  int get itemCount => ((payload['data']?['detail'] as List?) ?? []).length;

  Map<String, dynamic> toJson() => {
        'sale_id': saleId,
        'user_key': userKey,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
        'status': status.name,
        'error': error,
      };

  factory OutboxSale.fromJson(Map<String, dynamic> j) => OutboxSale(
        saleId: '${j['sale_id']}',
        userKey: '${j['user_key'] ?? ''}',
        payload: (j['payload'] as Map).cast<String, dynamic>(),
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        status: j['status'] == 'failed' ? OutboxStatus.failed : OutboxStatus.pending,
        error: j['error'] as String?,
      );
}

enum SubmitOutcome { saved, queued, rejected }

class SubmitResult {
  final SubmitOutcome outcome;
  final String saleId;
  final String? message;
  SubmitResult(this.outcome, this.saleId, [this.message]);
}

/// Antrean nota offline-first. Alur: nota diberi sale_id (UUID) -> DISIMPAN LOKAL DULU -> dikirim. Bila kirim
/// sukses, server dikonfirmasi lewat `salestatus` sebelum data lokal dihapus. Bila jaringan gagal, nota tetap
/// di antrean dan dikirim otomatis saat online kembali -- per transaksi (satu gagal tidak menahan yang lain
/// kecuali gangguan jaringan). Galat penolakan server (400/403/404/409) menandai nota FAILED (tidak dicoba
/// terus-menerus) agar kasir bisa melihat alasannya. Padanan utils/salesOutbox.ts di web.
class SalesOutbox extends ChangeNotifier {
  SalesOutbox._();
  static final SalesOutbox instance = SalesOutbox._();

  static const _file = 'outbox';
  final _api = SalesApi();
  final List<OutboxSale> _items = [];
  bool _loaded = false;
  bool _syncing = false;
  Timer? _timer;

  List<OutboxSale> get items => List.unmodifiable(_items);
  int get pendingCount => _items.where((e) => e.status == OutboxStatus.pending).length;
  int get failedCount => _items.where((e) => e.status == OutboxStatus.failed).length;
  bool get syncing => _syncing;

  Future<void> init() async {
    await _load();
    ConnectivityMonitor.instance.addListener(() {
      if (ConnectivityMonitor.instance.isOnline) syncAll();
    });
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => syncAll());
    unawaited(syncAll());
  }

  Future<void> _load() async {
    if (_loaded) return;
    final raw = await OfflineStore.instance.read(_file, []);
    _items
      ..clear()
      ..addAll((raw as List).map((e) => OutboxSale.fromJson((e as Map).cast<String, dynamic>())));
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await OfflineStore.instance.write(_file, _items.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<String> _currentUserKey() async =>
      await Storage.get(AppConstants.userGoldIdKey) ?? '';

  /// Kirim nota SEKARANG dengan jaminan tidak hilang: simpan lokal dulu, lalu coba kirim.
  ///  - saved    : server menyimpan (sudah diverifikasi), data lokal dihapus
  ///  - queued   : jaringan gagal, nota aman di antrean & akan dikirim otomatis
  ///  - rejected : server menolak (mis. stok kurang) -- TIDAK diantre, pesan untuk kasir
  Future<SubmitResult> submit(Map<String, dynamic> payload) async {
    await _load();
    final header = (payload['data']['header'] as Map).cast<String, dynamic>();
    final saleId = (header['sale_id'] as String?) ?? newSaleId();
    header['sale_id'] = saleId;
    final entry = OutboxSale(
      saleId: saleId,
      userKey: await _currentUserKey(),
      payload: payload,
      createdAt: DateTime.now(),
    );
    _items.add(entry);
    await _persist();

    if (!ConnectivityMonitor.instance.isOnline) {
      return SubmitResult(SubmitOutcome.queued, saleId);
    }
    final res = await _sendOne(entry);
    switch (res) {
      case _Send.saved:
        return SubmitResult(SubmitOutcome.saved, saleId);
      case _Send.rejected:
        final msg = entry.error;
        _items.remove(entry); // penolakan langsung: kasir masih memegang keranjang, jangan diantre
        await _persist();
        return SubmitResult(SubmitOutcome.rejected, saleId, msg);
      case _Send.network:
        return SubmitResult(SubmitOutcome.queued, saleId);
    }
  }

  Future<_Send> _sendOne(OutboxSale e) async {
    e.attempts++;
    try {
      final resp = await _api.insertSales(e.payload);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // konfirmasi ke server sebelum menghapus data lokal
        final st = await _api.saleStatuses([e.saleId]);
        if (st != null && st[e.saleId] == true) {
          _items.remove(e);
          await _persist();
          return _Send.saved;
        }
        await _persist();
        return _Send.network; // belum terkonfirmasi: biarkan di antrean, coba lagi (idempoten)
      }
      if ([400, 403, 404, 409, 422].contains(resp.statusCode)) {
        String msg = 'Ditolak server (${resp.statusCode})';
        try {
          msg = jsonDecode(resp.body)['error']?.toString() ?? msg;
        } catch (_) {}
        e.status = OutboxStatus.failed;
        e.error = msg;
        await _persist();
        return _Send.rejected;
      }
      // 5xx / 401 / 429 dll: gangguan sementara -> tetap pending
      await _persist();
      return _Send.network;
    } catch (_) {
      ConnectivityMonitor.instance.reportNetworkFailure();
      await _persist();
      return _Send.network;
    }
  }

  /// Kirim semua nota pending milik akun yang sedang login, berurutan. Berhenti bila jaringan gagal.
  Future<void> syncAll() async {
    if (_syncing) return;
    await _load();
    final userKey = await _currentUserKey();
    final todo = _items
        .where((e) => e.status == OutboxStatus.pending && (e.userKey.isEmpty || e.userKey == userKey))
        .toList();
    if (todo.isEmpty) return;
    _syncing = true;
    notifyListeners();
    try {
      for (final e in todo) {
        final r = await _sendOne(e);
        if (r == _Send.network) break;
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Coba ulang nota FAILED (mis. setelah stok ditambah).
  Future<void> retry(String saleId) async {
    for (final e in _items.where((e) => e.saleId == saleId)) {
      e.status = OutboxStatus.pending;
      e.error = null;
    }
    await _persist();
    await syncAll();
  }

  /// Buang nota (hanya untuk yang FAILED / atas keputusan kasir).
  Future<void> discard(String saleId) async {
    _items.removeWhere((e) => e.saleId == saleId);
    await _persist();
  }
}

enum _Send { saved, rejected, network }
