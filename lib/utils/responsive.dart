import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Breakpoint mengikuti MUI di web: xs < 600 (HP), sm 600-899 (HP landscape /
/// tablet kecil), md >= 900 (tablet). Dipakai supaya layar Android yang sama
/// tetap rapi dari HP 360px sampai tablet 10" landscape.
class Breakpoints {
  static const double sm = 600;
  static const double md = 900;
  static const double lg = 1200;
}

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  /// HP portrait (< 600dp)
  bool get isCompact => screenWidth < Breakpoints.sm;

  /// HP landscape / tablet kecil (600-899dp)
  bool get isMedium =>
      screenWidth >= Breakpoints.sm && screenWidth < Breakpoints.md;

  /// tablet (>= 900dp)
  bool get isExpanded => screenWidth >= Breakpoints.md;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// Layar pendek (HP landscape ~360-412dp tinggi): kurangi jarak vertikal &
  /// pastikan konten bisa di-scroll.
  bool get isShort => screenHeight < 500;

  /// Padding tepi halaman: 16 (HP) / 20 / 24 (tablet) -- padanan Container
  /// `px: { xs: 1.5, sm: 2, md: 3 }` di AppShell web.
  double get pagePadding => isCompact ? 16 : (isMedium ? 20 : 24);

  EdgeInsets get pageInsets => EdgeInsets.all(pagePadding);

  /// Lebar maksimum konten halaman (web: Container maxWidth="xl").
  double get contentMaxWidth => 1200;

  /// Lebar dialog: penuh (minus margin) di HP, dibatasi di tablet.
  double dialogMaxWidth([double max = 560]) =>
      math.min(screenWidth - 24, max);

  /// Jumlah kolom grid berdasarkan lebar minimum tiap kartu.
  int columnsFor({double minTileWidth = 160, int min = 1, int max = 4}) {
    final available = screenWidth - pagePadding * 2;
    return (available / minTileWidth).floor().clamp(min, max);
  }

  /// Pilih nilai berdasarkan breakpoint (xs wajib; sm/md opsional).
  T responsive<T>(T xs, {T? sm, T? md}) {
    if (isExpanded) return md ?? sm ?? xs;
    if (isMedium) return sm ?? xs;
    return xs;
  }
}

/// Membatasi lebar konten di tablet & menengahkannya (padanan Container
/// maxWidth di web) -- di HP tidak berpengaruh.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Badan halaman standar: scroll vertikal + padding responsif + lebar
/// maksimum di tablet. Semua layar ber-AppBar sebaiknya memakai ini supaya
/// konten tidak pernah terpotong di layar pendek (HP landscape).
class PageBody extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final ScrollController? controller;

  const PageBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: controller,
        padding: padding ?? context.pageInsets,
        child: ContentWidth(
          maxWidth: maxWidth ?? context.contentMaxWidth,
          child: child,
        ),
      ),
    );
  }
}

/// Tabel lebar (DataTable) yang bisa di-scroll horizontal di HP, tapi tetap
/// memenuhi lebar penuh di tablet -- padanan `overflow-x: auto` di web.
class HorizontalScrollTable extends StatelessWidget {
  final Widget child;

  const HorizontalScrollTable({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Deret tombol aksi yang otomatis turun baris di layar sempit (padanan
/// Stack direction row + flexWrap di web). Di HP sempit tombol jadi lebar
/// penuh supaya label tidak terpotong.
class ResponsiveActions extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final WrapAlignment alignment;

  /// jika true, di HP (< 600dp) setiap tombol dipaksa lebar penuh & disusun
  /// vertikal
  final bool fullWidthOnCompact;

  const ResponsiveActions({
    super.key,
    required this.children,
    this.spacing = 8,
    this.alignment = WrapAlignment.start,
    this.fullWidthOnCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (fullWidthOnCompact && context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
