import '../providers/language_provider.dart';

/// Panduan tooltip pertama kali per role (2026-10-22, porting dari
/// gold-gym-fe-next-js-ts utils/onboardingSteps.ts). [menuTitle] HARUS sama
/// persis dengan judul menu di widgets/app_drawer.dart -- tour menyorot menu
/// drawer ASLI lewat judul itu. Langkah yang menunya tidak tampil (mis. menu
/// staff yang ditolak owner) otomatis dilewati.
class OnboardingStep {
  final String menuTitle;
  final String text;
  const OnboardingStep(this.menuTitle, this.text);
}

const String onboardingRoleSeller = 'SELLER';
const String onboardingRoleStaff = 'STAFF';
const String onboardingRoleBuyer = 'BUYER';

String onboardingWelcome(String role, LanguageProvider lang) {
  switch (role) {
    case onboardingRoleSeller:
      return lang.get(
          "Let's walk through the main menus to get your store up and running.",
          'Yuk, kita telusuri menu-menu utama supaya toko Anda siap jalan.');
    case onboardingRoleStaff:
      return lang.get("Here's a quick look at the menus you'll use every day.",
          'Ini sekilas menu-menu yang akan Anda pakai sehari-hari.');
    default:
      return lang.get("Here's how to pick a store and place your first order.",
          'Begini cara memilih outlet dan melakukan pesanan pertama Anda.');
  }
}

List<OnboardingStep> onboardingStepsFor(
    String role, bool isTherapy, LanguageProvider lang) {
  if (role == onboardingRoleSeller) {
    return [
      OnboardingStep(
          'Ganti Outlet',
          lang.get(
              'Create your first outlet here (or switch between outlets if you have more than one).',
              'Buat outlet pertama Anda di sini (atau pindah antar outlet kalau sudah punya lebih dari satu).')),
      // Outlet THERAPY tidak punya menu "Atur Meja" (diganti "Booking Terapi").
      if (isTherapy)
        OnboardingStep(
            'Booking Terapi',
            lang.get('Manage your therapy appointment slots here.',
                'Atur jadwal slot terapi pelanggan Anda di sini.'))
      else
        OnboardingStep(
            'Atur Meja',
            lang.get(
                'Set up your areas (indoor/outdoor) and tables -- needed before taking dine-in orders.',
                'Atur area (indoor/outdoor) dan meja di sini -- perlu diisi sebelum menerima transaksi dine-in.')),
      OnboardingStep(
          'Staff',
          lang.get(
              'Add staff accounts and control which menus each of them can access.',
              'Tambahkan akun staff dan atur menu apa saja yang boleh mereka akses.')),
      OnboardingStep(
          'Point of Sale',
          lang.get('This is where you record sales at the counter.',
              'Di sinilah Anda mencatat transaksi penjualan di kasir.')),
      OnboardingStep(
          'Antrian POS',
          lang.get(
              'If you turn on the queue number feature (in outlet settings), track it here.',
              'Kalau Anda mengaktifkan fitur nomor antrian (di pengaturan outlet), pantau di sini.')),
      OnboardingStep(
          'Laporan Penjualan',
          lang.get('Daily, weekly, and monthly sales reports live here.',
              'Laporan penjualan harian, mingguan, dan bulanan ada di sini.')),
    ];
  }
  if (role == onboardingRoleStaff) {
    return [
      OnboardingStep(
          'Absen',
          lang.get(
              'Clock in here when your shift starts, and clock out when it ends.',
              'Absen masuk di sini saat mulai kerja, dan absen pulang saat selesai.')),
      OnboardingStep(
          'Point of Sale',
          lang.get('Record sales for customers here.',
              'Catat transaksi penjualan pelanggan di sini.')),
      OnboardingStep(
          'Antrian POS',
          lang.get(
              'If the outlet uses queue numbers, manage the queue board here.',
              'Kalau outlet memakai nomor antrian, kelola papan antrian di sini.')),
    ];
  }
  return [
    OnboardingStep(
        'Pilih Outlet',
        lang.get('Browse and pick a store to shop from here.',
            'Jelajahi dan pilih outlet untuk belanja di sini.')),
    OnboardingStep(
        'Pesan Barang',
        lang.get('Order products from the store you picked.',
            'Pesan produk dari outlet yang Anda pilih.')),
    OnboardingStep(
        'Pesanan Saya',
        lang.get('Track the status of your orders here.',
            'Pantau status pesanan Anda di sini.')),
    OnboardingStep(
        'Antrian Saya',
        lang.get(
            'If a cashier links your account to an in-store transaction, your queue number shows here.',
            'Kalau kasir mengaitkan akun Anda ke transaksi di toko, nomor antrian Anda muncul di sini.')),
  ];
}
