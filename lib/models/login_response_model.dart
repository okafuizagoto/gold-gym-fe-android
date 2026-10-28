class LoginResponseModel {
  final String tokenType;
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final int expiresIn;
  final int forceChangePassword;
  final String username;
  final String role;
  final int goldId;
  // flag "sudah mendaftar sebagai pembeli" (Y/N) — menu Mode Pembeli
  final String buyerYn;
  // flag ADMIN: paksa sembunyikan menu Daftar Pembeli / Mode Pembeli
  // terlepas dari buyerYn di atas (lihat layar admin Akses Daftar/Mode Pembeli)
  final String menuDaftarPembeli;
  final String menuModePembeli;
  final bool emailVerified;
  // Negara akun (kode ISO2, mis. "ID"); kosong untuk akun lama. Menentukan bahasa awal.
  final String countryIso2;

  LoginResponseModel({
    required this.tokenType,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.expiresIn,
    required this.forceChangePassword,
    required this.username,
    this.role = 'SELLER',
    this.goldId = 0,
    this.buyerYn = 'N',
    this.menuDaftarPembeli = 'Y',
    this.menuModePembeli = 'Y',
    this.emailVerified = false,
    this.countryIso2 = '',
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      tokenType: json['data']['token_type'] ?? '',
      accessToken: json['data']['access_token'] ?? '',
      refreshToken: json['data']['refresh_token'] ?? '',
      expiresAt: json['data']['expires_at'] ?? 0,
      expiresIn: json['data']['expires_at'] ?? 0,
      forceChangePassword: json['data']['force_change_password'] ?? 0,
      username: json['metadata']['username'] ?? '',
      role: json['metadata']['role'] ?? 'SELLER',
      goldId: json['metadata']['gold_id'] ?? 0,
      buyerYn: json['metadata']['buyer_yn'] ?? 'N',
      menuDaftarPembeli: json['metadata']['menu_daftar_pembeli'] ?? 'Y',
      menuModePembeli: json['metadata']['menu_mode_pembeli'] ?? 'Y',
      emailVerified: json['metadata']['email_verified'] == true,
      countryIso2: (json['metadata']['country_iso2'] ?? '').toString(),
    );
  }

  String get bearerToken => '$tokenType $accessToken';
}
