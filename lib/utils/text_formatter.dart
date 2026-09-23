import 'package:intl/intl.dart';

class TextFormatter {
  // Format Rupiah: 1000000 → "Rp1.000.000"
  static String formatRupiah(double nominal) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return 'Rp${formatter.format(nominal).replaceAll(',', '.')}';
  }

  // Format Currency (generic)
  static String formatCurrency(
    double value,
    String locale,
    String currencyCode,
  ) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: '',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  // Format Date: DateTime → "DD MMM YYYY HH:mm"
  static String formatDate(DateTime date, [String format = 'dd MMM yyyy HH:mm']) {
    final formatter = DateFormat(format, 'id_ID');
    return formatter.format(date);
  }

  // Format Date with day name: "dddd, DD MMMM YYYY HH:mm:ss"
  static String formatDateFull(DateTime date) {
    final formatter = DateFormat('EEEE, dd MMMM yyyy HH:mm:ss', 'id_ID');
    return formatter.format(date);
  }

  // Capitalize first letter
  static String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Format jam dari sale_transtime backend (disimpan mentah "HHMMSS", mis.
  // "143025") -> "14:30:25". Fallback ke nilai asli kalau formatnya lain.
  static String formatTimeHms(String raw) {
    final t = raw.trim();
    if (t.length == 6 && RegExp(r'^\d{6}$').hasMatch(t)) {
      return '${t.substring(0, 2)}:${t.substring(2, 4)}:${t.substring(4, 6)}';
    }
    if (t.length == 4 && RegExp(r'^\d{4}$').hasMatch(t)) {
      return '${t.substring(0, 2)}:${t.substring(2, 4)}:00';
    }
    return t;
  }

  // Get month short name
  static String getMonthShortName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
