class SlotBookingModel {
  final String bookingId;
  final String custName;
  final String registeredYn;
  final String status; // PAID / UNPAID
  final int duration;
  final String start;
  final String therapyType; // SOFA / DRAGON / KURSI
  // harga tersimpan di booking (0 = belum ada); untuk booking belum bayar
  // bisa berisi harga custom yang dikunci penjual saat booking dibuat
  final int price;

  SlotBookingModel({
    required this.bookingId,
    required this.custName,
    required this.registeredYn,
    required this.status,
    required this.duration,
    required this.start,
    this.therapyType = '',
    this.price = 0,
  });

  bool get isPaid => status == 'PAID';
  bool get isRegistered => registeredYn == 'Y';
  String get therapyLabel {
    switch (therapyType) {
      case 'DRAGON':
        return 'Kursi Dragon';
      case 'KURSI':
        return 'Kursi';
      case 'SOFA':
        return 'Sofa';
      default:
        return '';
    }
  }

  factory SlotBookingModel.fromJson(Map<String, dynamic> json) {
    return SlotBookingModel(
      bookingId: json['booking_id'] ?? '',
      custName: json['cust_name'] ?? '',
      registeredYn: json['registered_yn'] ?? 'N',
      status: json['status'] ?? 'UNPAID',
      duration: json['duration'] ?? 30,
      start: json['start'] ?? '',
      therapyType: json['therapy_type'] ?? '',
      price: int.tryParse('${json['price'] ?? '0'}'.split('.').first) ?? 0,
    );
  }
}

class SlotModel {
  final String start;
  final String end;
  final int capacity;
  final int used;
  final int available;
  final bool hasUnpaid;
  final bool full;
  final bool past;
  final List<SlotBookingModel> bookings;

  SlotModel({
    required this.start,
    required this.end,
    required this.capacity,
    required this.used,
    required this.available,
    required this.hasUnpaid,
    required this.full,
    required this.past,
    required this.bookings,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      start: json['start'] ?? '',
      end: json['end'] ?? '',
      capacity: json['capacity'] ?? 3,
      used: json['used'] ?? 0,
      available: json['available'] ?? 0,
      hasUnpaid: json['has_unpaid'] ?? false,
      full: json['full'] ?? false,
      past: json['past'] ?? false,
      bookings: ((json['bookings'] ?? []) as List)
          .map((e) => SlotBookingModel.fromJson(e))
          .toList(),
    );
  }
}

class BuyerModel {
  final int goldId;
  final String nama;
  final String toko;
  final String email;
  final String nomorHp;

  BuyerModel({
    required this.goldId,
    required this.nama,
    this.toko = '',
    required this.email,
    required this.nomorHp,
  });

  factory BuyerModel.fromJson(Map<String, dynamic> json) {
    return BuyerModel(
      goldId: json['gold_id'] ?? 0,
      nama: json['gold_nama'] ?? '',
      toko: json['gold_toko'] ?? '',
      email: json['gold_email'] ?? '',
      nomorHp: json['gold_nomorhp'] ?? '',
    );
  }
}
