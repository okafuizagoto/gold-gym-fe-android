import 'package:http/http.dart' as http;
import 'api_client.dart';

class BookingApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// Grid slot 30 menit satu outlet pada satu tanggal (YYYY-MM-DD).
  Future<http.Response> getSlots(String outcode, String date) {
    return _client.get("/gold-gym/v2/booking", queryParams: {
      "type": "slots",
      "code": outcode,
      "date": date,
    });
  }

  /// Autocomplete pembeli terdaftar (untuk penjual).
  Future<http.Response> searchBuyers(String name) {
    final queryParams = {"type": "buyers"};
    if (name.isNotEmpty) {
      queryParams["name"] = name;
    }
    return _client.get("/gold-gym/v2/booking", queryParams: queryParams);
  }

  /// Insert booking. Booking berbayar → response berisi sale_id untuk nota PDF.
  /// therapyType: SOFA / DRAGON. customPrice > 0 = harga input sendiri
  /// (hanya dihormati backend untuk role SELLER/ADMIN).
  Future<http.Response> insertBooking({
    required String outcode,
    required String date,
    required String start,
    required int duration,
    int custId = 0,
    String custName = '',
    required bool paid,
    int itemId = 0,
    String payType = '',
    String therapyType = '',
    int customPrice = 0,
  }) {
    return _client.post("/gold-gym/v2/booking?type=insertbooking", {
      "data": {
        "outcode": outcode,
        "date": date,
        "start": start,
        "duration": duration,
        "cust_id": custId,
        "cust_name": custName,
        "paid": paid,
        "item_id": itemId,
        "pay_type": payType,
        "therapy_type": therapyType,
        "custom_price": customPrice,
      }
    });
  }

  /// Bayar booking yang masih UNPAID. Response berisi sale_id.
  /// Backend otomatis menggabung 2x30 menit bersebelahan (nama & tipe sama)
  /// menjadi satu nota 1 jam dengan harga 1 jam.
  Future<http.Response> payBooking(String bookingId, int itemId,
      {int customPrice = 0}) {
    return _client.put(
        "/gold-gym/v2/booking?type=paybooking&bookingid=$bookingId&itemid=$itemId&customprice=$customPrice",
        {});
  }

  /// Hapus booking UNPAID (khusus penjual/admin); tercatat di booking_remove_log.
  Future<http.Response> removeBooking(String bookingId) {
    return _client.delete(
        "/gold-gym/v2/booking?type=removebooking&bookingid=$bookingId");
  }
}
