import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class PaymentApi {
  final ApiClient _client = ApiClient();

  /// Mulai transaksi QRIS baru: backend minta QR ke Midtrans lalu simpan
  /// transaksi lokal berstatus PENDING. Balikan berisi order_id (dipakai
  /// polling status) dan qr_url (ditampilkan ke pembeli).
  Future<http.Response> chargeQris(String outcode, double amount) {
    return _client.post("/gold-gym/v2/payment?type=chargeqris", {
      "outcode": outcode,
      "amount": amount,
    });
  }

  /// Polling status transaksi QRIS berdasarkan order_id dari chargeQris.
  Future<http.Response> getStatus(String orderId) {
    return _client.get("/gold-gym/v2/payment", queryParams: {
      "type": "status",
      "order_id": orderId,
    });
  }

  /// Laporan transaksi payment QRIS -- KHUSUS ADMIN, lintas semua outlet
  /// (nama outlet & user sudah di-JOIN backend). Semua parameter opsional:
  /// outcode kosong = semua outlet, search cocok ke order_id/nama
  /// outlet/nama/email user, status kosong = semua status.
  Future<http.Response> getReport(
      {String outcode = '',
      String status = '',
      String search = '',
      int page = 0,
      int length = 0}) {
    final params = {"type": "report"};
    if (outcode.isNotEmpty) params["outcode"] = outcode;
    if (status.isNotEmpty) params["status"] = status;
    if (search.isNotEmpty) params["search"] = search;
    if (page > 0) params["page"] = page.toString();
    if (length > 0) params["length"] = length.toString();
    return _client.get("/gold-gym/v2/payment", queryParams: params);
  }
}

/// Hasil parse response chargeQris.
class QrisCharge {
  final String orderId;
  final String qrUrl;
  final String status;

  QrisCharge({required this.orderId, required this.qrUrl, required this.status});

  factory QrisCharge.fromResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return QrisCharge(
      orderId: data['order_id'] as String,
      qrUrl: data['qr_url'] as String,
      status: data['status'] as String,
    );
  }
}

/// Hasil parse response getStatus.
class QrisStatus {
  final String status;

  QrisStatus({required this.status});

  factory QrisStatus.fromResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return QrisStatus(status: data['payment_status'] as String);
  }
}

/// 1 baris hasil getReport -- nama outlet & user sudah di-JOIN backend.
class PaymentReportRow {
  final String orderId;
  final String outletName;
  final String userName;
  final String userEmail;
  final double amount;
  final String method;
  final String status;
  final String? saleId;
  final DateTime createdAt;

  PaymentReportRow({
    required this.orderId,
    required this.outletName,
    required this.userName,
    required this.userEmail,
    required this.amount,
    required this.method,
    required this.status,
    required this.saleId,
    required this.createdAt,
  });

  factory PaymentReportRow.fromJson(Map<String, dynamic> json) {
    return PaymentReportRow(
      orderId: json['payment_order_id'] as String,
      outletName: json['outlet_name'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      userEmail: json['user_email'] as String? ?? '',
      amount: (json['payment_amount'] as num).toDouble(),
      method: json['payment_method'] as String? ?? '',
      status: json['payment_status'] as String? ?? '',
      saleId: json['payment_sale_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static List<PaymentReportRow> listFromResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PaymentReportRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
