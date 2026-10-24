import 'dart:math';

/// Pembuat password acak (dipakai penjual saat mendaftarkan staff). Memakai Random.secure(), tanpa karakter yang
/// mudah tertukar (0 O 1 l I), selalu memuat huruf besar, huruf kecil, angka, dan 1 simbol -> memenuhi kebijakan
/// password dan masuk level "Sangat kuat" (>= 12 karakter + simbol).
/// Padanan utils/passwordGenerator.ts (web) -- ubah keduanya bersamaan.
const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _lower = 'abcdefghijkmnopqrstuvwxyz';
const _digit = '23456789';
const _symbol = '#@!\$%*?';

String generatePassword([int length = 12]) {
  final rnd = Random.secure();
  String pick(String chars) => chars[rnd.nextInt(chars.length)];
  final len = max(length, 8);
  const all = _upper + _lower + _digit + _symbol;
  final chars = [pick(_upper), pick(_lower), pick(_digit), pick(_symbol)];
  while (chars.length < len) {
    chars.add(pick(all));
  }
  chars.shuffle(rnd);
  return chars.join();
}
