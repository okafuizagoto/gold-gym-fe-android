import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/expense_model.dart';
import 'dart:convert';

/// Padanan services/expense.ts. Modul expense (gold-gym-be-v2) --
/// pencatatan pengeluaran operasional per outlet, PRIVATE milik SELLER
/// pemilik outlet (tidak ada listing admin lintas-tenant).
class ExpenseApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// POST /gold-gym/v2/expense -- outcode WAJIB (outlet aktif penjual).
  Future<http.Response> create({
    required String category,
    String? vendor,
    required double amount,
    required String date,
    String? description,
    bool isRecurring = false,
    String? recurringPeriod,
    required String outcode,
  }) {
    return _client.post('/gold-gym/v2/expense', {
      'category': category,
      if (vendor != null && vendor.isNotEmpty) 'vendor': vendor,
      'amount': amount,
      'date': date,
      if (description != null && description.isNotEmpty)
        'description': description,
      'is_recurring': isRecurring,
      if (isRecurring && recurringPeriod != null && recurringPeriod.isNotEmpty)
        'recurring_period': recurringPeriod,
      'outcode': outcode,
    });
  }

  /// GET /gold-gym/v2/expense -- filter opsional, kosong = tanpa filter itu.
  Future<List<Expense>?> list({
    String? outcode,
    String? category,
    String? from,
    String? to,
  }) async {
    final query = <String, String>{
      if (outcode != null && outcode.isNotEmpty) 'outcode': outcode,
      if (category != null && category.isNotEmpty) 'category': category,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    };
    final response = await _client.get('/gold-gym/v2/expense',
        queryParams: query.isEmpty ? null : query);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List?) ?? [];
    return rows.map((e) => Expense.fromJson(e)).toList();
  }

  /// GET /gold-gym/v2/expense/summary -- default rentang bulan berjalan
  /// kalau from/to kosong.
  Future<ExpenseSummary?> summary({
    String? outcode,
    String? from,
    String? to,
  }) async {
    final query = <String, String>{
      if (outcode != null && outcode.isNotEmpty) 'outcode': outcode,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    };
    final response = await _client.get('/gold-gym/v2/expense/summary',
        queryParams: query.isEmpty ? null : query);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ExpenseSummary.fromJson(body['data'] ?? {});
  }

  /// DELETE /gold-gym/v2/expense/:id -- 403 kalau pemanggil STAFF (bukan
  /// pemilik outlet asli).
  Future<http.Response> deleteExpense(int expenseId) {
    return _client.delete('/gold-gym/v2/expense/$expenseId');
  }
}
