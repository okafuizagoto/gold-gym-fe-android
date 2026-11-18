/// Kontak bantuan, rekening transfer, dan permintaan bayar langganan (2026-11-18). Padanan web: services/manualPay.ts.
class SupportContact {
  final String whatsapp; // 62xxxxxxxx (format wa.me); kosong = tombol bantuan disembunyikan
  final String name;
  final String hours;
  final String email;
  const SupportContact({this.whatsapp = '', this.name = '', this.hours = '', this.email = ''});

  factory SupportContact.fromJson(Map<String, dynamic> j) => SupportContact(
        whatsapp: (j['whatsapp'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        hours: (j['hours'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
      );
  Map<String, dynamic> toJson() => {'whatsapp': whatsapp, 'name': name, 'hours': hours, 'email': email};
}

class BankInfo {
  final bool enabled;
  final String bankName;
  final String accountNo;
  final String accountName;
  final String note;
  const BankInfo({this.enabled = false, this.bankName = '', this.accountNo = '', this.accountName = '', this.note = ''});

  factory BankInfo.fromJson(Map<String, dynamic> j) => BankInfo(
        enabled: j['enabled'] == true,
        bankName: (j['bank_name'] ?? '').toString(),
        accountNo: (j['account_no'] ?? '').toString(),
        accountName: (j['account_name'] ?? '').toString(),
        note: (j['note'] ?? '').toString(),
      );
  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'bank_name': bankName, 'account_no': accountNo, 'account_name': accountName, 'note': note};
}

class PayRequest {
  final int id;
  final String reference;
  final String ownerEmail;
  final String ownerName;
  final String ownerShop;
  final String plan;
  final String cycle; // MONTHLY / YEARLY
  final double amount;
  final String status; // PENDING / APPROVED / REJECTED / CANCELLED
  final String bankRef;
  final String adminNote;
  final String decidedBy;
  final DateTime? decidedAt;
  final DateTime? periodEnd;
  final DateTime? createdAt;

  const PayRequest({
    required this.id,
    required this.reference,
    this.ownerEmail = '',
    this.ownerName = '',
    this.ownerShop = '',
    required this.plan,
    required this.cycle,
    required this.amount,
    required this.status,
    this.bankRef = '',
    this.adminNote = '',
    this.decidedBy = '',
    this.decidedAt,
    this.periodEnd,
    this.createdAt,
  });

  bool get yearly => cycle == 'YEARLY';

  static DateTime? _t(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory PayRequest.fromJson(Map<String, dynamic> j) => PayRequest(
        id: (j['id'] as num?)?.toInt() ?? 0,
        reference: (j['reference'] ?? '').toString(),
        ownerEmail: (j['owner_email'] ?? '').toString(),
        ownerName: (j['owner_name'] ?? '').toString(),
        ownerShop: (j['owner_shop'] ?? '').toString(),
        plan: (j['plan'] ?? '').toString(),
        cycle: (j['cycle'] ?? 'MONTHLY').toString(),
        amount: double.tryParse((j['amount'] ?? '0').toString()) ?? 0,
        status: (j['status'] ?? '').toString(),
        bankRef: (j['bank_ref'] ?? '').toString(),
        adminNote: (j['admin_note'] ?? '').toString(),
        decidedBy: (j['decided_by'] ?? '').toString(),
        decidedAt: _t(j['decided_at']),
        periodEnd: _t(j['period_end']),
        createdAt: _t(j['created_at']),
      );
}
