/// Tipe Outlet (2026-10-22, porting dari gold-gym-fe-next-js-ts
/// utils/outletType.ts): BEDA dari Bidang Usaha (bidang_usaha.dart) -- field ini
/// benar-benar MENENTUKAN perilaku (THERAPY = aktifkan Booking Terapi, pelanggan
/// tidak wajib diisi di POS). Daftar di bawah BUKAN whitelist pembatas -- backend
/// (entity/outlet.NormalizeOutletType) menerima teks bebas apa pun, daftar ini cuma
/// usulan cepat untuk search box (lihat new_outlet_screen.dart, Autocomplete freeSolo).
class OutletTypeOption {
  final String value;
  final String label;
  const OutletTypeOption(this.value, this.label);
}

/// Satu-satunya tipe dengan perilaku khusus. Admin bisa sembunyikan opsi ini dari
/// daftar lewat menu Akses Admin (web) -- lihat core_api.getOutletTypeSettings().
const String outletTypeTherapy = 'THERAPY';

const List<OutletTypeOption> outletTypeOptions = [
  OutletTypeOption('RETAIL', 'Retail / Toko'),
  OutletTypeOption('GROSIR', 'Grosir & Distributor'),
  OutletTypeOption('RESTORAN', 'Makanan & Minuman (Restoran/Kafe)'),
  OutletTypeOption('JASA', 'Jasa Umum (laundry, percetakan, reparasi, dll)'),
  OutletTypeOption(outletTypeTherapy, 'Jasa Terapi & Spa (aktifkan Booking Terapi)'),
  OutletTypeOption('KECANTIKAN', 'Salon & Kecantikan'),
  OutletTypeOption('FASHION', 'Fashion & Pakaian'),
  OutletTypeOption('OTOMOTIF', 'Otomotif & Bengkel'),
  OutletTypeOption('ELEKTRONIK', 'Elektronik & Gadget'),
  OutletTypeOption('FURNITURE', 'Furniture & Dekorasi Rumah'),
  OutletTypeOption('BANGUNAN', 'Bahan Bangunan & Konstruksi'),
  OutletTypeOption('PERTANIAN', 'Pertanian & Perkebunan'),
  OutletTypeOption('PETERNAKAN', 'Peternakan'),
  OutletTypeOption('PERIKANAN', 'Perikanan'),
  OutletTypeOption('PETSHOP', 'Pet Shop & Grooming Hewan'),
  OutletTypeOption('FLORIS', 'Toko Bunga / Florist'),
  OutletTypeOption('PERCETAKAN', 'Percetakan & Fotokopi'),
  OutletTypeOption('FOTOGRAFI', 'Fotografi & Videografi'),
  OutletTypeOption('EVENT', 'Event & Wedding Organizer'),
  OutletTypeOption('PENDIDIKAN', 'Pendidikan & Les'),
  OutletTypeOption('KESEHATAN', 'Apotek & Klinik Kesehatan'),
  OutletTypeOption('OLAHRAGA', 'Olahraga & Fitness'),
  OutletTypeOption('HIBURAN', 'Hiburan & Rekreasi'),
  OutletTypeOption('HOTEL', 'Hotel & Penginapan'),
  OutletTypeOption('TRANSPORTASI', 'Transportasi & Rental Kendaraan'),
  OutletTypeOption('LOGISTIK', 'Logistik & Ekspedisi'),
  OutletTypeOption('PROPERTI', 'Properti & Real Estate'),
  OutletTypeOption('TEKNOLOGI', 'Teknologi & Jasa IT'),
  OutletTypeOption('PULSAPPOB', 'Konter Pulsa & PPOB'),
];

const String outletTypeDefault = 'RETAIL';

/// Opsi yang ditampilkan ke user -- sembunyikan THERAPY kalau admin menonaktifkannya
/// (core_api.getOutletTypeSettings()). Outlet THERAPY yang sudah ada tetap THERAPY.
List<OutletTypeOption> visibleOutletTypeOptions(bool therapyVisible) {
  if (therapyVisible) return outletTypeOptions;
  return outletTypeOptions.where((o) => o.value != outletTypeTherapy).toList();
}

/// Cocokkan teks bebas (hasil ketik/pilih di search box) ke kode outlet_type yang
/// dikirim ke backend: match label/kode persis (case-insensitive) -> kode option itu;
/// tidak cocok -> dikirim apa adanya (trim), backend menormalisasi sendiri.
String resolveOutletTypeValue(String input) {
  final trimmed = input.trim();
  for (final o in outletTypeOptions) {
    if (o.label.toLowerCase() == trimmed.toLowerCase() ||
        o.value.toLowerCase() == trimmed.toLowerCase()) {
      return o.value;
    }
  }
  return trimmed;
}

/// Kebalikan dari resolveOutletTypeValue -- kode dikenal -> label-nya, kode custom -> apa adanya.
String outletTypeDisplayLabel(String value) {
  for (final o in outletTypeOptions) {
    if (o.value == value) return o.label;
  }
  return value;
}
