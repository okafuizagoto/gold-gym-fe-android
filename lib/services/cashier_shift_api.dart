import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Sesi kasir / shift dengan rekonsiliasi kas (2026-10-10, temuan QA POS #2).
/// Padanan services/cashierShift.ts.
class CashierShiftApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// GET /current: shift yang sedang berjalan di outlet (data null = belum ada shift dibuka).
  Future<http.Response> current(String outcode) {
    return _client.get('/gold-gym/v2/cashier-shift/current',
        queryParams: {'code': outcode});
  }

  /// GET /preview: ekspektasi kas TANPA menutup shift -- dipakai layar "Tutup Shift" sebelum
  /// kasir memasukkan hasil hitung fisik.
  Future<http.Response> preview(String outcode) {
    return _client.get('/gold-gym/v2/cashier-shift/preview',
        queryParams: {'code': outcode});
  }

  /// GET riwayat shift (audit kas), terbaru dulu.
  Future<http.Response> history(String outcode, {int limit = 50}) {
    return _client.get('/gold-gym/v2/cashier-shift', queryParams: {
      'code': outcode,
      'limit': '$limit',
    });
  }

  /// GET /ledger: buku kas satu hari (Kas History). date "YYYY-MM-DD".
  Future<http.Response> ledger(String outcode, String date) {
    return _client.get('/gold-gym/v2/cashier-shift/ledger',
        queryParams: {'code': outcode, 'date': date});
  }

  /// GET /handoff: kas akhir sesi sebelumnya + Tarik Kas sesudahnya (cek serah-terima saat buka sesi).
  Future<http.Response> handoff(String outcode) {
    return _client.get('/gold-gym/v2/cashier-shift/handoff',
        queryParams: {'code': outcode});
  }

  /// POST /open: buka sesi kasir baru dengan modal awal (+ alasan bila berbeda dari kas akhir sesi sebelumnya).
  Future<http.Response> open(String outcode, double openingCash,
      {String handoffReason = ''}) {
    return _client.post('/gold-gym/v2/cashier-shift/open', {
      'outcode': outcode,
      'opening_cash': openingCash,
      'handoff_reason': handoffReason,
    });
  }

  /// POST /verify-handoff: penjual memverifikasi selisih serah-terima sebuah sesi (catatan wajib; sekali, tidak bisa diubah).
  Future<http.Response> verifyHandoff(int shiftId, String note) {
    return _client.post('/gold-gym/v2/cashier-shift/verify-handoff',
        {'shift_id': shiftId, 'note': note});
  }

  /// POST /cash-move: catat Tarik Kas (penjual / staff yang diizinkan).
  Future<http.Response> addCashMove(
      String outcode, String kind, double amount, String reason) {
    return _client.post('/gold-gym/v2/cashier-shift/cash-move', {
      'outcode': outcode,
      'kind': kind,
      'amount': amount,
      'reason': reason,
    });
  }

  /// GET /cash-moves: Tarik Kas (incoming=false) atau Tambah Kas (incoming=true) satu hari (default hari ini).
  Future<http.Response> cashMoves(String outcode,
      {required bool incoming, String? date}) {
    return _client.get('/gold-gym/v2/cashier-shift/cash-moves', queryParams: {
      'code': outcode,
      'dir': incoming ? 'in' : 'out',
      if (date != null) 'date': date,
    });
  }

  /// POST /close: tutup sesi kasir dengan hasil hitung fisik uang di laci.
  Future<http.Response> close(int shiftId, double countedCash, String note) {
    return _client.post('/gold-gym/v2/cashier-shift/close', {
      'shift_id': shiftId,
      'counted_cash': countedCash,
      'note': note,
    });
  }
}
