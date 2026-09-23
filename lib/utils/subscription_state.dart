import 'dart:convert';
import 'constants.dart';
import 'storage.dart';
import '../services/subscription_api.dart';

/// Status langganan pemilik usaha (dari backend goldgym), disimpan di cache lokal supaya
/// menu/banner bisa membacanya tanpa menunggu jaringan. Backend TETAP penegak aturan (403
/// dengan kode); ini hanya untuk tampilan (gembok menu, banner, layar Langganan).
///
/// Padanan utils/subscription.ts (Next.js) -- ubah keduanya bersamaan.
class SubscriptionInfo {
  final String plan;
  final String planName;
  final String status; // TRIAL | ACTIVE | EXPIRED | LIFETIME
  final String source;
  final int? periodEnd; // unix detik; null = tanpa batas
  final int? daysLeft;
  final bool readOnly;
  final List<String> features;
  final int maxOutlets; // -1 = tak terbatas
  final int maxUsers; // termasuk pemilik; -1 = tak terbatas
  final int usersUsed;
  final int trialDays;

  const SubscriptionInfo({
    required this.plan,
    required this.planName,
    required this.status,
    required this.source,
    required this.periodEnd,
    required this.daysLeft,
    required this.readOnly,
    required this.features,
    required this.maxOutlets,
    required this.maxUsers,
    required this.usersUsed,
    required this.trialDays,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> d) => SubscriptionInfo(
        plan: '${d['plan'] ?? ''}',
        planName: '${d['plan_name'] ?? ''}',
        status: '${d['status'] ?? 'ACTIVE'}',
        source: '${d['source'] ?? ''}',
        periodEnd:
            d['period_end'] is num ? (d['period_end'] as num).toInt() : null,
        daysLeft:
            d['days_left'] is num ? (d['days_left'] as num).toInt() : null,
        readOnly: d['read_only'] == true,
        features: (d['features'] is List)
            ? (d['features'] as List).map((e) => '$e').toList()
            : const <String>[],
        maxOutlets:
            d['max_outlets'] is num ? (d['max_outlets'] as num).toInt() : -1,
        maxUsers: d['max_users'] is num ? (d['max_users'] as num).toInt() : -1,
        usersUsed:
            d['users_used'] is num ? (d['users_used'] as num).toInt() : 0,
        trialDays:
            d['trial_days'] is num ? (d['trial_days'] as num).toInt() : 15,
      );

  Map<String, dynamic> toJson() => {
        'plan': plan,
        'plan_name': planName,
        'status': status,
        'source': source,
        'period_end': periodEnd,
        'days_left': daysLeft,
        'read_only': readOnly,
        'features': features,
        'max_outlets': maxOutlets,
        'max_users': maxUsers,
        'users_used': usersUsed,
        'trial_days': trialDays,
      };
}

class PlanDef {
  final String id;
  final String name;
  final int priceMonthly;
  final int priceYearly;
  final int maxOutlets;
  final int maxUsers;
  final List<String> features;

  const PlanDef({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.priceYearly,
    required this.maxOutlets,
    required this.maxUsers,
    required this.features,
  });

  factory PlanDef.fromJson(Map<String, dynamic> d) => PlanDef(
        id: '${d['id'] ?? ''}',
        name: '${d['name'] ?? ''}',
        priceMonthly:
            d['price_monthly'] is num ? (d['price_monthly'] as num).toInt() : 0,
        priceYearly:
            d['price_yearly'] is num ? (d['price_yearly'] as num).toInt() : 0,
        maxOutlets:
            d['max_outlets'] is num ? (d['max_outlets'] as num).toInt() : -1,
        maxUsers: d['max_users'] is num ? (d['max_users'] as num).toInt() : -1,
        features: (d['features'] is List)
            ? (d['features'] as List).map((e) => '$e').toList()
            : const <String>[],
      );
}

/// Cache status langganan di memori + penyimpanan lokal.
class SubscriptionState {
  static const _key = 'subscription_info';
  static SubscriptionInfo? current;

  /// Baca cache lokal (cepat, tanpa jaringan).
  static Future<SubscriptionInfo?> load() async {
    final raw = await Storage.get(_key);
    if (raw == null || raw.isEmpty) return current = null;
    try {
      final m = jsonDecode(raw);
      if (m is Map<String, dynamic>) current = SubscriptionInfo.fromJson(m);
    } catch (_) {
      current = null;
    }
    return current;
  }

  /// Segarkan dari backend. Hanya untuk SELLER/STAFF (pembeli & admin tidak punya langganan).
  static Future<SubscriptionInfo?> refresh() async {
    final role = await Storage.get(AppConstants.userRoleKey);
    if (role != AppConstants.roleSeller && role != AppConstants.roleStaff) {
      return current;
    }
    try {
      final res = await SubscriptionApi().getMine();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body is Map ? body['data'] : null;
        if (data is Map<String, dynamic>) {
          current = SubscriptionInfo.fromJson(data);
          await Storage.set(_key, jsonEncode(current!.toJson()));
        }
      }
    } catch (_) {
      // jaringan / sesi berakhir: tetap pakai cache
    }
    return current;
  }

  static Future<void> clear() async {
    current = null;
    await Storage.delete(_key);
  }

  /// Fitur ada di paket? Status belum diketahui -> true (fail-open, backend tetap menolak).
  static bool hasFeature(String feature) {
    final s = current;
    return s == null || s.features.contains(feature);
  }

  static bool get isReadOnly => current?.readOnly == true;
}

/// Nama fitur untuk tampilan (kunci = kunci fitur backend).
const featureLabels = <String, String>{
  'pos': 'Point of Sale',
  'sales_history': 'Riwayat penjualan & bukti pembayaran',
  'reports_basic': 'Laporan harian, mingguan, bulanan',
  'stock': 'Stok & katalog barang',
  'customers': 'Data pelanggan',
  'qris': 'QRIS & transfer bank',
  'receipt': 'Struk digital',
  'backup_manual': 'Backup data manual',
  'booking': 'Booking terapi',
  'marketplace': 'Marketplace pembeli',
  'discount_voucher': 'Diskon & voucher',
  'staff_management': 'Karyawan (akun, akses, absensi)',
  'expenses': 'Pencatatan pengeluaran',
  'export_reports': 'Export laporan PDF/Excel',
  'backup_daily': 'Backup data harian otomatis',
  'trend_dashboard': 'Dashboard tren penjualan',
  'priority_support': 'Dukungan prioritas',
};

String featureLabel(String key) => featureLabels[key] ?? key;

String formatRupiah(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp$buf';
}

String formatLimit(int n, String unit) =>
    n < 0 ? '$unit tak terbatas' : '$n $unit';

String formatDate(int? unixSeconds) {
  if (unixSeconds == null) return '-';
  const bulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];
  final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
}
