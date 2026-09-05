class AppConstants {
  static const String appName = 'Okejual';
  static const String version = '1.0.0';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String expiresAtKey = 'expires_at';
  static const String userNIPKey = 'userNIP';
  static const String userEmail = 'userEmail';
  static const String languageKey = 'language';
  static const String accessListKey = 'access_list';
  static const String customMenusKey = 'user_custom_menus';
  // Harus sama dengan key yang ditulis outlet_screen ('outcode'); dulu 'out_code'
  // sehingga main.dart tidak pernah menemukan outlet tersimpan.
  static const String outcode = 'outcode';
  static const String userRoleKey = 'user_role';
  static const String outletTypeKey = 'outlet_type';
  static const String userGoldIdKey = 'user_gold_id';
  // mode tampilan untuk penjual/admin: 'BUYER' = sedang berbelanja sebagai
  // pembeli (menu drawer berubah); kosong/'SELLER' = mode penjual normal
  static const String shopModeKey = 'shop_mode';
  static const String shopModeBuyer = 'BUYER';
  // flag akun "sudah mendaftar sebagai pembeli" (gold_buyer_yn dari login);
  // Y = menu Mode Pembeli tampil & menu Daftar Pembeli hilang
  static const String userIsBuyerKey = 'user_is_buyer';
  // flag ADMIN (dari login): paksa sembunyikan menu Daftar Pembeli / Mode
  // Pembeli terlepas dari status userIsBuyerKey di atas. Default 'Y' (tampil).
  static const String menuDaftarPembeliKey = 'menu_daftar_pembeli';
  static const String menuModePembeliKey = 'menu_mode_pembeli';
  // outlet tujuan belanja mode pembeli (persist antar buka aplikasi)
  static const String buyerOutcodeKey = 'buyer_outcode';
  static const String buyerOutletNameKey = 'buyer_outlet_name';
  // gold_id pemilik outlet tujuan (outlet_code tidak unik global, jadi wajib)
  static const String buyerOutletGoldIdKey = 'buyer_outlet_gold_id';

  // Roles
  static const String roleSeller = 'SELLER';
  static const String roleBuyer = 'BUYER';
  static const String roleAdmin = 'ADMIN';

  // Outlet types
  static const String outletTherapy = 'THERAPY';

  // Tipe terapi (booking)
  static const String therapySofa = 'SOFA';
  static const String therapyDragon = 'DRAGON';
  static const String therapyKursi = 'KURSI';

  // Payment Types
  static const String paymentCash = 'TUNAI';
  static const String paymentBank = 'BANK';
  static const String paymentDebit = 'DEBIT';
  static const String paymentTransfer = 'TRANSFER';

  // Default Values
  static const String defaultLanguage = 'EN';
}
