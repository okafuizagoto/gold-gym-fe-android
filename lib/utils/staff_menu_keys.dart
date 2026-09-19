/// Daftar menu_key yang boleh di-checklist di layar Akses Staff -- key =
/// route path (konvensi sama dengan AppRoutes). Grup admin, item mode
/// pembeli, About Us, dan Absen SENGAJA tidak masuk daftar ini (lihat
/// app_drawer.dart -- About Us & Absen selalu tampil, tidak pernah
/// difilter oleh denied_menu_keys).
class StaffMenuKeys {
  static const List<StaffMenuKeyOption> options = [
    StaffMenuKeyOption('/', 'Dashboard'),
    StaffMenuKeyOption('/booking', 'Booking Terapi'),
    StaffMenuKeyOption('/penjualan', 'Point of Sale'),
    StaffMenuKeyOption('/pesanan-masuk', 'Pesanan Masuk'),
    StaffMenuKeyOption('/history-sales', 'Sales History'),
    StaffMenuKeyOption('/laporan', 'Laporan Penjualan'),
    StaffMenuKeyOption('/meja-area', 'Meja & Area'),
    StaffMenuKeyOption('/kelola-meja', 'Kelola Meja'),
    StaffMenuKeyOption('/stock-barang', 'Stock'),
    StaffMenuKeyOption('/add-items', 'Add Items'),
    StaffMenuKeyOption('/diskon', 'Diskon'),
    StaffMenuKeyOption('/daftar-customer', 'Daftar Customer'),
    StaffMenuKeyOption('/daftar-pembeli', 'Daftar Pembeli'),
    StaffMenuKeyOption('/outlet', 'Ganti Outlet'),
    StaffMenuKeyOption('/storage', 'Storage'),
  ];
}

class StaffMenuKeyOption {
  final String key;
  final String label;
  const StaffMenuKeyOption(this.key, this.label);
}
