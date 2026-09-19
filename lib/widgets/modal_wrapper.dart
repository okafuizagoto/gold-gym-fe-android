import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/responsive.dart';

/// Pembungkus isi dialog (web: ModalWrapper). Lebar TIDAK PERNAH melebihi
/// layar (lebar yang diminta pemanggil, mis. 900, dipangkas otomatis di HP),
/// tinggi dibatasi 90% layar dan isinya bisa di-scroll supaya tidak ada
/// bagian yang terpotong di HP kecil/landscape.
class ModalWrapper extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final bool scrollable;
  final EdgeInsets? padding;

  const ModalWrapper({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.scrollable = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final size = context.screenSize;
    final compact = context.isCompact;
    final maxWidth = size.width - 24;
    final requested = width ?? math.min(size.width * 0.92, 560);
    final effectiveWidth = math.min(requested, maxWidth);
    final maxHeight = size.height * 0.9;
    final effectiveHeight =
        height == null ? null : math.min(height!, maxHeight);

    return Center(
      child: Container(
        width: effectiveWidth,
        height: effectiveHeight,
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: padding ?? EdgeInsets.all(compact ? 20 : 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF101828).withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: scrollable
            ? SingleChildScrollView(child: child)
            : child,
      ),
    );
  }
}

// Helper function to show modal dialog
Future<T?> showModalDialog<T>({
  required BuildContext context,
  required Widget child,
  double? width,
  double? height,
  bool scrollable = false,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ModalWrapper(
        width: width,
        height: height,
        scrollable: scrollable,
        child: child,
      ),
    ),
  );
}
