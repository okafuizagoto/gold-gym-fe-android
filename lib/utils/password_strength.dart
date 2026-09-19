/// Kebijakan & kekuatan password (SEMUA akun/role: daftar, dibuat owner,
/// ganti/reset).
///
/// WAJIB (backend menolak kalau tidak terpenuhi): minimal 6 karakter (maks
/// 128), minimal 1 huruf besar, 1 huruf kecil, 1 angka. Simbol (# ! @ dst.)
/// OPSIONAL -- hanya menambah kekuatan.
///
/// Level kekuatan (meter, gaya indikator akun Google):
///   0 Lemah        : aturan wajib belum terpenuhi, ATAU terlalu umum/berulang
///   1 Cukup        : aturan wajib terpenuhi, 6-7 karakter tanpa simbol
///   2 Kuat         : + (>= 8 karakter ATAU pakai simbol)
///   3 Sangat kuat  : >= 12 karakter DAN pakai simbol
///
/// Aturan sama persis dengan utils/passwordStrength.ts (Next.js) dan backend
/// (Garrison-POS/goldgym passwordpolicy.go, gold-gym-be-v2
/// pkg/passwordpolicy) -- ubah semuanya bersamaan.
const passwordMinLen = 6;
const passwordMaxLen = 128;

const passwordPolicyMessage =
    'Password minimal 6 karakter dan harus mengandung huruf besar, huruf kecil, dan angka.';

const passwordLevelLabels = ['Lemah', 'Cukup', 'Kuat', 'Sangat kuat'];

class PasswordEvaluation {
  final bool hasMinLength;
  final bool hasUpper;
  final bool hasLower;
  final bool hasDigit;
  final bool hasSymbol;

  /// memenuhi semua aturan WAJIB
  final bool valid;

  /// 0..3 (lihat level di atas)
  final int level;
  final String label;

  /// petunjuk singkat kalau level rendah karena umum/berulang, else ''
  final String hint;

  const PasswordEvaluation({
    required this.hasMinLength,
    required this.hasUpper,
    required this.hasLower,
    required this.hasDigit,
    required this.hasSymbol,
    required this.valid,
    required this.level,
    required this.label,
    required this.hint,
  });
}

const _common = [
  'password',
  'passw0rd',
  'qwerty',
  '123456',
  '12345678',
  'admin',
  'welcome',
  'letmein',
  'iloveyou',
  'abc123',
  'okejual',
  'login',
];

final _digit = RegExp(r'\p{Nd}', unicode: true);
final _nonSymbol = RegExp(r'[\p{L}\p{Nd}\s]', unicode: true);

bool _isCommonOrRepetitive(String pw) {
  final l = pw.toLowerCase();
  if (_common.any(l.contains)) return true;
  if (l.runes.toSet().length <= 2 && l.runes.length >= 4) return true;
  return false;
}

PasswordEvaluation evaluatePassword(String pw) {
  final chars = pw.runes.map(String.fromCharCode).toList();
  final len = chars.length;
  final hasUpper =
      chars.any((c) => c != c.toLowerCase() && c == c.toUpperCase());
  final hasLower =
      chars.any((c) => c != c.toUpperCase() && c == c.toLowerCase());
  final hasDigit = chars.any(_digit.hasMatch);
  final hasSymbol = chars.any((c) => !_nonSymbol.hasMatch(c));
  final hasMinLength = len >= passwordMinLen && len <= passwordMaxLen;
  final valid = hasMinLength && hasUpper && hasLower && hasDigit;

  var level = 0;
  var hint = '';
  if (valid) {
    if (_isCommonOrRepetitive(pw)) {
      level = 0;
      hint = 'Terlalu umum atau berulang, hindari kata yang mudah ditebak.';
    } else if (len >= 12 && hasSymbol) {
      level = 3;
    } else if (len >= 8 || hasSymbol) {
      level = 2;
    } else {
      level = 1;
    }
  }
  return PasswordEvaluation(
    hasMinLength: hasMinLength,
    hasUpper: hasUpper,
    hasLower: hasLower,
    hasDigit: hasDigit,
    hasSymbol: hasSymbol,
    valid: valid,
    level: level,
    label: passwordLevelLabels[level],
    hint: hint,
  );
}
