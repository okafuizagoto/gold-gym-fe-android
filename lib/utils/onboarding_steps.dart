import '../providers/language_provider.dart';

/// Panduan tooltip pertama kali per role (2026-10-22, diperluas 2026-10-23; porting dari
/// gold-gym-fe-next-js-ts utils/onboardingSteps.ts). Langkah menu menyorot menu drawer ASLI lewat
/// judulnya ([menuTitle] HARUS sama persis dengan judul di widgets/app_drawer.dart), lalu "Lanjut"
/// membawa user ke halaman menunya ([goto]) dan langkah halaman menyorot tombol penting di sana
/// ([targetId] = id TourTarget, lihat widgets/tour_target.dart). Langkah yang elemennya tidak ada
/// (menu ditolak owner, tombol belum muncul karena data kosong) dilewati otomatis.
enum OnboardingStepKind { menu, page, done }

class OnboardingStep {
  final OnboardingStepKind kind;
  final String? menuTitle;
  final String? targetId;
  final String? page;
  final String? goto;
  final String text;
  const OnboardingStep._(this.kind, this.text,
      {this.menuTitle, this.targetId, this.page, this.goto});

  factory OnboardingStep.menu(String title, String goto, String text) =>
      OnboardingStep._(OnboardingStepKind.menu, text,
          menuTitle: title, goto: goto);

  factory OnboardingStep.page(String page, String id, String text,
          {String? goto}) =>
      OnboardingStep._(OnboardingStepKind.page, text,
          targetId: id, page: page, goto: goto);

  factory OnboardingStep.done(String text) =>
      OnboardingStep._(OnboardingStepKind.done, text);

  String get title => menuTitle ?? '';
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
  final t = lang.get;
  final done = OnboardingStep.done(t(
      'You can replay this guide anytime from the "Panduan Penggunaan" menu.',
      'Anda bisa mengulang panduan ini kapan saja lewat menu "Panduan Penggunaan".'));

  final posOpenShift = OnboardingStep.page(
      '/penjualan',
      'pos-open-shift',
      t('A cashier session must be open before you can sell. Tap this button to open one (the owner or any staff can).',
          'Sesi kasir harus dibuka dulu sebelum bisa berjualan. Ketuk tombol ini untuk membukanya (owner atau staff mana pun bisa).'));
  final posSearch = OnboardingStep.page(
      '/penjualan',
      'pos-search',
      t('Search a product by name or scan its barcode, then tap it to add it to the cart.',
          'Cari produk lewat nama atau scan barcode, lalu ketuk produk untuk memasukkannya ke keranjang.'));
  final posPay = OnboardingStep.page(
      '/penjualan',
      'pos-pay',
      t('PAYMENT: choose how the customer pays, then save the sale. Use HOLD (next to it) to park a transaction and serve someone else first.',
          'BAYAR: pilih cara bayar pelanggan, lalu simpan transaksi. Tombol TAHAN di sebelahnya menyimpan sementara transaksi supaya Anda bisa melayani pelanggan lain dulu.'));
  final queueMenu =
      (String text) => OnboardingStep.menu('Antrian POS', '/antrian-pos', text);
  final queueAdvance = OnboardingStep.page(
      '/antrian-pos',
      'queue-advance',
      t('PROCESS / FINISH: move a queue number forward (Waiting -> Processing -> Done).',
          'PROSES / SELESAI: majukan status nomor antrian (Menunggu -> Diproses -> Selesai).'));

  if (role == onboardingRoleSeller) {
    return [
      OnboardingStep.menu(
          'Ganti Outlet',
          '/outlet',
          t('Create your first outlet here (or switch between outlets if you have more than one). Tap Next to open this page.',
              'Buat outlet pertama Anda di sini (atau pindah antar outlet kalau sudah punya lebih dari satu). Ketuk Lanjut untuk membuka halamannya.')),
      OnboardingStep.page(
          '/outlet',
          'outlet-confirm',
          t('Pick an outlet from the list, then tap CONFIRM to work inside it.',
              'Pilih outlet dari daftar, lalu ketuk CONFIRM untuk bekerja di outlet itu.')),
      OnboardingStep.page(
          '/outlet',
          'outlet-new',
          t('NEW OUTLET: add another store or branch.',
              'NEW OUTLET: tambahkan toko atau cabang lain.')),
      OnboardingStep.page(
          '/outlet',
          'outlet-list',
          t('LIST OUTLET: see all your outlets and turn the queue number feature on or off. Tap Next to open it.',
              'LIST OUTLET: lihat semua outlet Anda dan aktifkan/nonaktifkan fitur nomor antrian. Ketuk Lanjut untuk membukanya.'),
          goto: '/list-outlet'),
      OnboardingStep.page(
          '/list-outlet',
          'outlet-queue-toggle',
          t("QUEUE button: ON gives every sale a queue number and shows it on the Antrian POS board. Leave it OFF if you don't need queue numbers.",
              'Tombol ANTRIAN: AKTIF = tiap transaksi mendapat nomor antrian dan tampil di papan Antrian POS. Biarkan NONAKTIF kalau tidak butuh nomor antrian.')),
      // Outlet THERAPY tidak punya menu "Atur Meja" (diganti "Booking Terapi").
      if (isTherapy)
        OnboardingStep.menu(
            'Booking Terapi',
            '/booking',
            t('Manage your therapy appointment slots here. Tap Next to open this page.',
                'Atur jadwal slot terapi pelanggan Anda di sini. Ketuk Lanjut untuk membukanya.'))
      else ...[
        OnboardingStep.menu(
            'Atur Meja',
            '/meja-area',
            t('Set up your areas (indoor/outdoor) and tables -- needed before taking dine-in orders. Tap Next to open this page.',
                'Atur area (indoor/outdoor) dan meja di sini -- perlu diisi sebelum menerima transaksi dine-in. Ketuk Lanjut untuk membukanya.')),
        OnboardingStep.page(
            '/meja-area',
            'meja-add',
            t('ADD TABLE: create a new table (or a new area on the Area tab).',
                'TAMBAH MEJA: buat meja baru (atau area baru di tab Area).')),
      ],
      OnboardingStep.menu(
          'Staff',
          '/daftar-staff',
          t('Add staff accounts and control which menus each of them can access. Tap Next to open this page.',
              'Tambahkan akun staff dan atur menu apa saja yang boleh mereka akses. Ketuk Lanjut untuk membukanya.')),
      OnboardingStep.page(
          '/daftar-staff',
          'staff-add',
          t('REGISTER STAFF: create a staff account and tick the menus they may use (sensitive menus are unticked by default; your choice is remembered).',
              'DAFTARKAN STAFF: buat akun staff dan centang menu yang boleh dipakai (menu sensitif tidak dicentang secara default; pilihan Anda diingat).'),
          goto: '/akses-staff'),
      OnboardingStep.page(
          '/akses-staff',
          'staff-access-save',
          t('Tick the menus a staff member may use, then tap SAVE. Unticked menus stay hidden for them.',
              'Centang menu yang boleh dipakai staff, lalu ketuk SIMPAN. Menu yang tidak dicentang tetap tersembunyi untuknya.')),
      OnboardingStep.menu(
          'Kas',
          '/cashier-shift',
          t('The Cash group holds Cashier Session, Cash History, Withdraw Cash and Add Cash. Open a cashier session before selling. Tap Next to open it.',
              'Grup Kas berisi Sesi Kasir, Kas History, Tarik Kas, dan Tambah Kas. Buka sesi kasir sebelum mulai berjualan. Ketuk Lanjut untuk membukanya.')),
      OnboardingStep.page(
          '/cashier-shift',
          'shift-main',
          t('OPEN CASHIER SESSION: enter the starting cash. The app compares it with the previous session\'s closing cash; if it differs, you must write a reason (your name is recorded). At the end of the day tap the same button to close and reconcile.',
              'BUKA SESI KASIR: isi modal awal. Aplikasi membandingkannya dengan kas akhir sesi sebelumnya; jika berbeda, Anda wajib menulis alasannya (nama Anda tercatat). Di akhir hari ketuk tombol yang sama untuk menutup dan rekonsiliasi kas.')),
      OnboardingStep.menu(
          'Kas History',
          '/kas-history',
          t('The daily cash book: every cash sale, refund, Withdraw/Add Cash and handover check, in time order. Tap Next to open it.',
              'Buku kas harian: semua penjualan tunai, refund, Tarik/Tambah Kas, dan cek serah-terima, urut waktu. Ketuk Lanjut untuk membukanya.')),
      OnboardingStep.page(
          '/kas-history',
          'kas-history-main',
          t('Colour guide: orange = Withdraw Cash, blue = Add Cash, red = handover difference that needs checking, green = handover OK or verified. The owner can VERIFY a difference (a note is required).',
              'Panduan warna: oranye = Tarik Kas, biru = Tambah Kas, merah = selisih serah-terima yang perlu dicek, hijau = serah-terima sesuai atau sudah terverifikasi. Penjual bisa MEMVERIFIKASI selisih (catatan wajib).')),
      OnboardingStep.menu(
          'Tarik Kas',
          '/tarik-kas',
          t('Record money taken OUT of the drawer (owner withdrawal, bank deposit, expense) with a reason. Tap Next to open it.',
              'Catat uang yang KELUAR dari laci (tarik owner, setor bank, pengeluaran) beserta alasannya. Ketuk Lanjut untuk membukanya.')),
      OnboardingStep.page(
          '/tarik-kas',
          'cash-move-save',
          t('Choose the type, enter the amount and the reason, then RECORD. Your name and the time are saved automatically and the record cannot be edited.',
              'Pilih jenis, isi jumlah dan alasan, lalu CATAT. Nama dan jam Anda tersimpan otomatis dan catatan tidak bisa diubah.')),
      OnboardingStep.menu(
          'Tambah Kas',
          '/tambah-kas',
          t('Record money put INTO the drawer (extra capital, other cash in) with a reason. Tap Next to open it.',
              'Catat uang yang MASUK ke laci (tambah modal, kas masuk lainnya) beserta alasannya. Ketuk Lanjut untuk membukanya.')),
      OnboardingStep.page(
          '/tambah-kas',
          'cash-move-save',
          t('Enter the amount and the reason, then RECORD. It appears in Cash History as Add Cash.',
              'Isi jumlah dan alasan, lalu CATAT. Tampil di Kas History sebagai Tambah Kas.')),
      OnboardingStep.menu(
          'Point of Sale',
          '/penjualan',
          t('This is where you record sales at the counter. Tap Next to open this page.',
              'Di sinilah Anda mencatat transaksi penjualan di kasir. Ketuk Lanjut untuk membukanya.')),
      posOpenShift,
      posSearch,
      posPay,
      queueMenu(t(
          'The queue board. It only works after you turn the QUEUE button on in the outlet list. Tap Next to open it.',
          'Papan antrian. Baru berfungsi setelah tombol ANTRIAN diaktifkan di daftar outlet. Ketuk Lanjut untuk membukanya.')),
      queueAdvance,
      OnboardingStep.menu(
          'Laporan Penjualan',
          '/laporan',
          t('Daily, weekly, and monthly sales reports live here. Tap Next to open it.',
              'Laporan penjualan harian, mingguan, dan bulanan ada di sini. Ketuk Lanjut untuk membukanya.')),
      done,
    ];
  }
  if (role == onboardingRoleStaff) {
    return [
      OnboardingStep.menu(
          'Absen',
          '/absen',
          t('Clock in here when your shift starts, and clock out when it ends. Tap Next to open this page.',
              'Absen masuk di sini saat mulai kerja, dan absen pulang saat selesai. Ketuk Lanjut untuk membukanya.')),
      OnboardingStep.page(
          '/absen',
          'absen-main',
          t('CLOCK IN when you start working. The same button becomes CLOCK OUT at the end of your shift.',
              'ABSEN MASUK saat mulai kerja. Tombol yang sama berubah jadi ABSEN PULANG saat shift selesai.')),
      OnboardingStep.menu(
          'Point of Sale',
          '/penjualan',
          t('Record sales for customers here. Tap Next to open this page.',
              'Catat transaksi penjualan pelanggan di sini. Ketuk Lanjut untuk membukanya.')),
      posOpenShift,
      posSearch,
      posPay,
      queueMenu(t(
          'If the outlet uses queue numbers, manage the queue board here. Tap Next to open it.',
          'Kalau outlet memakai nomor antrian, kelola papan antrian di sini. Ketuk Lanjut untuk membukanya.')),
      queueAdvance,
      done,
    ];
  }
  return [
    OnboardingStep.menu(
        'Pilih Outlet',
        '/pilih-outlet',
        t('Browse and pick a store to shop from here. Tap Next to open this page.',
            'Jelajahi dan pilih outlet untuk belanja di sini. Ketuk Lanjut untuk membukanya.')),
    OnboardingStep.page(
        '/pilih-outlet',
        'pilih-outlet-start',
        t('After you pick a store, tap this button to start ordering from it.',
            'Setelah memilih outlet, ketuk tombol ini untuk mulai memesan dari outlet tersebut.')),
    OnboardingStep.menu(
        'Pesan Barang',
        '/belanja',
        t('Order products from the store you picked. Tap Next to open this page.',
            'Pesan produk dari outlet yang Anda pilih. Ketuk Lanjut untuk membukanya.')),
    OnboardingStep.page(
        '/belanja',
        'belanja-add',
        t('ADD: put a product in your basket.',
            'TAMBAH: masukkan produk ke keranjang belanja Anda.')),
    OnboardingStep.page(
        '/belanja',
        'belanja-pay',
        t('PAY: choose how to pay and send your order to the seller.',
            'BAYAR: pilih cara bayar dan kirim pesanan Anda ke penjual.')),
    OnboardingStep.menu(
        'Pesanan Saya',
        '/pesanan-saya',
        t('Track the status of your orders here. Tap Next to open this page.',
            'Pantau status pesanan Anda di sini. Ketuk Lanjut untuk membukanya.')),
    OnboardingStep.page(
        '/pesanan-saya',
        'pesanan-detail',
        t('DETAIL: see the items and status of an order.',
            'DETAIL: lihat isi dan status sebuah pesanan.')),
    OnboardingStep.menu(
        'Antrian Saya',
        '/antrian-saya',
        t('If a cashier links your account to an in-store transaction, your queue number shows here. Tap Next to open it.',
            'Kalau kasir mengaitkan akun Anda ke transaksi di toko, nomor antrian Anda muncul di sini. Ketuk Lanjut untuk membukanya.')),
    done,
  ];
}
