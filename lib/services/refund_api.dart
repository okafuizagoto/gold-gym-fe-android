import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Padanan services/refund.ts -- backend internal/delivery/http/refund.
class RefundApi {
  static const _base = '/gold-gym/v2/refund';
  final ApiClient _client = ApiClient();

  Future<http.Response> list({
    String outcode = '',
    String search = '',
    int page = 1,
    int length = 20,
  }) =>
      _client.get(_base, queryParams: {
        'type': 'list',
        if (outcode.isNotEmpty) 'outcode': outcode,
        if (search.isNotEmpty) 'search': search,
        'page': '$page',
        'length': '$length',
      });

  Future<http.Response> detail(String refundId) =>
      _client.get(_base, queryParams: {'type': 'detail', 'refund_id': refundId});

  /// Baris nota + sisa qty yang masih bisa di-refund.
  Future<http.Response> refundable(String saleId) =>
      _client.get(_base, queryParams: {'type': 'refundable', 'sale_id': saleId});

  Future<http.Response> create({
    required String saleId,
    required List<Map<String, dynamic>> items, // {td_id, qty, restock}
    required String method,
    required String reason,
  }) =>
      _client.post('$_base?type=create', {
        'sale_id': saleId,
        'items': items,
        'method': method,
        'reason': reason,
      });

  /// Struk refund PDF (58mm), sama seperti struk penjualan.
  Future<Uint8List?> getReceiptPdf(String refundId) async {
    try {
      final r = await _client.get(_base,
          queryParams: {'type': 'receipt', 'refund_id': refundId});
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }
}
