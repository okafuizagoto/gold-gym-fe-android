import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Notifikasi singkat bergaya web (react-hot-toast): pil melayang di atas,
/// hijau untuk sukses, merah untuk error, radius 12, lebar dibatasi supaya
/// rapi di tablet.
class Toast {
  static void _show(
    BuildContext context, {
    required Widget content,
    required Color background,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width > 520 ? (width - 480) / 2 : 16.0;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: content,
          backgroundColor: background,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          elevation: 2,
          margin: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  static Widget _row(IconData icon, String message) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  static void success(BuildContext context, String message) {
    _show(
      context,
      content: _row(Icons.check_circle_rounded, message),
      background: const Color(0xFF16A34A),
      duration: const Duration(seconds: 2),
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      content: _row(Icons.error_rounded, message),
      background: const Color(0xFFDC2626),
      duration: const Duration(seconds: 3),
    );
  }

  static void loading(BuildContext context, String message) {
    _show(
      context,
      content: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
      background: AppColors.ink,
      duration: const Duration(minutes: 1),
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      content: _row(Icons.info_rounded, message),
      background: AppColors.blue,
      duration: const Duration(seconds: 2),
    );
  }

  static void dismiss(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }
}
