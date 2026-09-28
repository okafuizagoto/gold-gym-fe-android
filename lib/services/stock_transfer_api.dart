import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/stock_transfer_model.dart';

/// Padanan services/stockTransfer.ts -- transfer stok antar outlet + surat jalan.
class StockTransferApi {
  final ApiClient _client = ApiClient();
  static const _base = '/gold-gym/v2/stock-transfer';

  /// POST -- 201, data = transfer (status DIBUAT).
  Future<http.Response> create({
    required String fromOutcode,
    required String toOutcode,
    String note = '',
    required List<({String stockId, int qty})> items,
  }) {
    return _client.post(_base, {
      'from_outcode': fromOutcode,
      'to_outcode': toOutcode,
      'note': note,
      'items': items.map((i) => {'stock_id': i.stockId, 'qty': i.qty}).toList(),
    });
  }

  /// direction: 'out' (pengirim) | 'in' (penerima) | null (keduanya). null bila gagal.
  Future<List<StockTransfer>?> list({String? outcode, String? direction}) async {
    final q = <String, String>{
      if (outcode != null && outcode.isNotEmpty) 'outcode': outcode,
      if (direction != null && direction.isNotEmpty) 'direction': direction,
    };
    final r = await _client.get(_base, queryParams: q.isEmpty ? null : q);
    if (r.statusCode != 200) return null;
    final rows = (jsonDecode(r.body)['data'] as List?) ?? [];
    return rows
        .map((e) => StockTransfer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StockTransfer?> get(int id) async {
    final r = await _client.get('$_base/$id');
    if (r.statusCode != 200) return null;
    final data = jsonDecode(r.body)['data'];
    return data == null
        ? null
        : StockTransfer.fromJson(data as Map<String, dynamic>);
  }

  /// 200 {status:done} atau 202 {status:pending_approval} (staf level PERSETUJUAN).
  Future<http.Response> send(int id) => _client.post('$_base/$id/send', {});
  Future<http.Response> receive(int id, String receiverName) =>
      _client.post('$_base/$id/receive', {'receiver_name': receiverName});
  Future<http.Response> cancel(int id, String reason) =>
      _client.post('$_base/$id/cancel', {'reason': reason});

  /// Pemilik saja.
  Future<http.Response> approve(int id) => _client.post('$_base/$id/approve', {});
  Future<http.Response> reject(int id) => _client.post('$_base/$id/reject', {});

  /// Surat jalan PDF; paper: 'a4' | '58' | '80'. null bila gagal.
  Future<Uint8List?> getPdf(int id, String paper) async {
    try {
      final r = await _client.get('$_base/$id/pdf', queryParams: {'paper': paper});
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  Future<TransferPermission?> myPermission() async {
    final r = await _client.get('$_base/permissions/me');
    if (r.statusCode != 200) return null;
    return TransferPermission.fromJson(
        (jsonDecode(r.body)['data'] ?? {}) as Map<String, dynamic>);
  }

  /// Pemilik saja.
  Future<TransferPermission?> getPermission(int staffGoldId) async {
    final r = await _client.get('$_base/permissions/$staffGoldId');
    if (r.statusCode != 200) return null;
    return TransferPermission.fromJson(
        (jsonDecode(r.body)['data'] ?? {}) as Map<String, dynamic>);
  }

  Future<http.Response> setPermission(
          int staffGoldId, String sendLevel, String receiveLevel) =>
      _client.put('$_base/permissions/$staffGoldId',
          {'send_level': sendLevel, 'receive_level': receiveLevel});
}
