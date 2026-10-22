import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../providers/language_provider.dart';

class _QuickLink {
  final IconData icon;
  final String title;
  final String route;
  const _QuickLink(this.icon, this.title, this.route);
}

class _QuickGroup {
  final IconData icon;
  final Color color;
  final String title;
  final String note;
  final List<_QuickLink> items;
  const _QuickGroup(this.icon, this.color, this.title, this.note, this.items);
}

/// Quick Menu Admin (2026-10-22, porting dari gold-gym-fe-next-js-ts
/// components/AdminQuickMenu.tsx) -- submenu "Akses Admin" dikelompokkan per
/// hubungan nyata, bukan daftar flat seperti di app_drawer.dart. Murni
/// navigasi, tidak ada aksi lintas-halaman/otomasi antar-setting.
///
/// CATATAN: "Fitur per Paket" (admin-plan-features) ada di grouping versi
/// web tapi BELUM ada layarnya di Android sama sekali (gap lama, bukan
/// bagian dari perubahan ini) -- sengaja tidak dimasukkan di sini supaya
/// tidak menunjuk ke route yang tidak ada.
class AdminQuickMenu extends StatelessWidget {
  final LanguageProvider lang;
  const AdminQuickMenu({super.key, required this.lang});

  List<_QuickGroup> _groups() {
    final outletUntukPembeli = _QuickLink(Icons.storefront_rounded,
        lang.get('Outlets for Buyers', 'Outlet untuk Pembeli'),
        AppRoutes.adminOutletPembeli);
    final posTanpaCustomer = _QuickLink(Icons.person_off_rounded,
        lang.get('POS Without Customer', 'POS Tanpa Customer'),
        AppRoutes.adminPosCustomer);
    final buktiPembayaran = _QuickLink(Icons.image_outlined,
        lang.get('Payment Proof Visibility', 'Visibilitas Bukti Pembayaran'),
        AppRoutes.adminProofAccess);
    final daftarAkun = _QuickLink(Icons.how_to_reg_rounded,
        lang.get('Account Registration', 'Daftar Akun'),
        AppRoutes.adminRegistrationMode);
    final tipeOutlet = _QuickLink(Icons.category_rounded,
        lang.get('Outlet Type', 'Tipe Outlet'),
        AppRoutes.adminOutletTypeSettings);
    final tampilanLangganan = _QuickLink(Icons.workspace_premium_rounded,
        lang.get('Subscription Display', 'Tampilan Langganan'),
        AppRoutes.adminLanggananTampilan);
    final hargaPaket = _QuickLink(Icons.sell_rounded,
        lang.get('Plan Pricing & Discount', 'Harga & Diskon Paket'),
        AppRoutes.adminPlanPricing);
    final aksesDaftarPembeli = _QuickLink(Icons.person_add_alt_rounded,
        lang.get('Buyer Registration Access', 'Akses Daftar Pembeli'),
        AppRoutes.adminAksesDaftarPembeli);
    final aksesModePembeli = _QuickLink(
        Icons.swap_horizontal_circle_outlined,
        lang.get('Buyer Mode Access', 'Akses Mode Pembeli'),
        AppRoutes.adminAksesModePembeli);
    final laporanQris = _QuickLink(Icons.receipt_long_rounded,
        lang.get('QRIS Payment Report', 'Laporan Pembayaran QRIS'),
        AppRoutes.adminPaymentReport);
    final storage = _QuickLink(Icons.data_usage_rounded,
        lang.get('Storage Usage (B2)', 'Penggunaan Storage (B2)'),
        AppRoutes.adminStorageUsage);
    final statistik = _QuickLink(Icons.assessment_rounded,
        lang.get('User Statistics', 'Statistik Pengguna'),
        AppRoutes.adminStatistikPengguna);
    final requestFitur = _QuickLink(Icons.feedback_outlined,
        lang.get('Feature Requests', 'Daftar Request Fitur'),
        AppRoutes.adminRequestFitur);
    final backup = _QuickLink(Icons.backup_rounded,
        lang.get('Daily Backup', 'Backup Data Harian'), AppRoutes.adminBackup);

    return [
      _QuickGroup(
        Icons.spa_rounded,
        const Color(0xFF7C3AED),
        lang.get('Therapy Booking', 'Booking Terapi'),
        lang.get(
            'Who can create a Therapy outlet, and whether it shows on the pricing page',
            'Siapa yang bisa buat outlet Terapi, dan apakah tampil di halaman harga'),
        [tipeOutlet, tampilanLangganan, posTanpaCustomer],
      ),
      _QuickGroup(
        Icons.storefront_rounded,
        const Color(0xFFEC4899),
        lang.get('Marketplace & Buyer Access', 'Marketplace & Akses Pembeli'),
        lang.get(
            'Which outlets buyers can see, and who can register as a buyer',
            'Outlet mana yang terlihat pembeli, dan siapa yang boleh daftar pembeli'),
        [
          outletUntukPembeli,
          tampilanLangganan,
          daftarAkun,
          aksesDaftarPembeli,
          aksesModePembeli,
        ],
      ),
      _QuickGroup(
        Icons.workspace_premium_rounded,
        AppColors.warning,
        lang.get('Plans & Subscription Pricing', 'Paket & Harga Langganan'),
        lang.get('What each plan costs', 'Harga tiap paket'),
        [hargaPaket, tampilanLangganan],
      ),
      _QuickGroup(
        Icons.payments_rounded,
        AppColors.info,
        lang.get('Payments & Transactions', 'Pembayaran & Transaksi'),
        lang.get('Payment proof and QRIS reporting',
            'Bukti pembayaran dan laporan QRIS'),
        [buktiPembayaran, laporanQris],
      ),
      _QuickGroup(
        Icons.build_rounded,
        AppColors.muted,
        lang.get('Operations & Others', 'Operasional & Lainnya'),
        lang.get('Not directly related to the groups above',
            'Tidak terkait langsung dengan grup-grup di atas'),
        [storage, backup, statistik, requestFitur],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final groups = _groups();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.get('Admin Quick Menu', 'Quick Menu Admin'),
            style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          lang.get('Admin menus grouped by what they actually affect together',
              'Menu admin dikelompokkan berdasarkan hubungan nyata antar-fiturnya'),
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: g.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(g.icon, size: 22, color: g.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.title, style: textTheme.titleSmall),
                              Text(g.note, style: textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final item in g.items)
                    ListTile(
                      dense: true,
                      leading:
                          Icon(item.icon, size: 20, color: AppColors.muted),
                      title: Text(item.title, style: textTheme.bodyMedium),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.disabled),
                      onTap: () =>
                          Navigator.pushNamed(context, item.route),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
