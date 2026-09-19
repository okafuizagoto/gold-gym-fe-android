/// Daftar nama menu yang bisa dipilih saat melaporkan perbaikan (type
/// PERBAIKAN) -- gabungan semua menu lintas role dari app_drawer.dart.
/// Ini cuma teks bebas yang disimpan ke `request_menu`, backend TIDAK
/// memvalidasi terhadap daftar tetap (supaya tidak perlu disinkronkan
/// manual tiap kali menu di app berubah) -- makanya ada opsi 'Lainnya'
/// yang membuka kolom teks bebas. URUTAN & LABEL harus SAMA PERSIS dengan
/// utils/featureRequestMenuOptions.ts (Next.js) supaya kedua platform
/// kembar.
class FeatureRequestMenuOptions {
  static const List<String> options = [
    'Dashboard',
    'Booking Terapi',
    'Point of Sale',
    'Pesanan Masuk',
    'Sales History',
    'Laporan Penjualan',
    'Meja & Area',
    'Kelola Meja',
    'Staff',
    'Absen',
    'Stock',
    'Add Items',
    'Diskon',
    'Daftar Customer',
    'Daftar Pembeli',
    'Ganti Outlet',
    'Mode Pembeli / Mode Penjual',
    'Storage',
    'QRIS Saya',
    'Pilih Outlet',
    'Pesan Barang',
    'Pesanan Saya',
    'About Us',
    'Lainnya',
  ];

  static const String lainnya = 'Lainnya';
}
