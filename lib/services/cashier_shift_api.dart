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

  /// POST /open: buka sesi kasir baru dengan modal awal.
  Future<http.Response> open(String outcode, double openingCash) {
    return _client.post('/gold-gym/v2/cashier-shift/open', {
      'outcode': outcode,
      'opening_cash': openingCash,
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
