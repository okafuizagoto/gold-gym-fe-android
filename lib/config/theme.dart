import 'package:flutter/material.dart';

/// Token warna -- SAMA PERSIS dengan web (gold-gym-fe-next-js-ts,
/// themes/light/index.ts `BRAND` + palette MUI). Kalau mengubah warna di
/// salah satu sisi, ubah juga di sisi lain supaya Android & web tetap kembar.
class AppColors {
  static const Color blue = Color(0xFF267BE4);
  static const Color blueDark = Color(0xFF1B5FB8);
  static const Color blueLight = Color(0xFFE8F1FD);
  static const Color teal = Color(0xFF6DBAB9);
  static const Color tealDark = Color(0xFF3F9694);
  static const Color tealLight = Color(0xFFE6F5F4);
  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6EAF2);
  static const Color ink = Color(0xFF1F2937);
  static const Color muted = Color(0xFF6B7280);
  static const Color disabled = Color(0xFF9CA3AF);

  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF15803D);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFB45309);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFB91C1C);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoLight = Color(0xFFE0F2FE);
  static const Color infoDark = Color(0xFF0369A1);

  /// latar pil/segmented tab & ikon empty-state (web: #EEF2F8)
  static const Color chipBg = Color(0xFFEEF2F8);

  /// latar header tabel (web: MuiTableCell head #F8FAFC)
  static const Color tableHead = Color(0xFFF8FAFC);

  /// gradasi logo (web: AuthCard / Sidebar)
  static const Color logoStart = Color(0xFFFF7A3D);
  static const Color logoEnd = Color(0xFFFF4F81);
}

/// Radius mengikuti web: tombol/input 10, card 16, dialog 18, chip 8.
class AppRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double card = 16;
  static const double dialog = 18;
  static const double pill = 999;
}

class AppTheme {
  // Nama lama tetap dipertahankan -- masih dipakai banyak layar.
  static const Color primaryTeal = AppColors.teal;
  static const Color primaryBlue = AppColors.blue;
  static const Color background = AppColors.background;

  static const String fontFamily = 'Inter';

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.blue,
      onPrimary: Colors.white,
      primaryContainer: AppColors.blueLight,
      onPrimaryContainer: AppColors.blueDark,
      secondary: AppColors.tealDark,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.tealLight,
      onSecondaryContainer: Color(0xFF2F7B79),
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.infoLight,
      onTertiaryContainer: AppColors.infoDark,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorLight,
      onErrorContainer: AppColors.errorDark,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.chipBg,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      shadow: Color(0xFF101828),
      scrim: Colors.black54,
      inverseSurface: AppColors.ink,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.blueLight,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
    );

    // Semua gaya diturunkan dari base (copyWith) supaya fontFamily Inter &
    // warna tinta tetap terbawa -- TextStyle baru yang berdiri sendiri akan
    // kehilangan fontFamily dan jatuh ke Roboto.
    final applied = base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
      fontFamily: fontFamily,
    );
    final textTheme = applied.copyWith(
      headlineMedium: applied.headlineMedium?.copyWith(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: applied.headlineSmall?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: applied.titleLarge
          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: applied.titleMedium
          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: applied.titleSmall
          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: applied.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: applied.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: applied.bodySmall
          ?.copyWith(fontSize: 12, height: 1.4, color: AppColors.muted),
      labelLarge: applied.labelLarge
          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: applied.labelMedium
          ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: applied.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
          letterSpacing: 0.4),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16);
    // 44dp = target sentuh nyaman di HP (web: 40 default / 48 large)
    const buttonMinSize = Size(0, 44);
    const buttonTextStyle = TextStyle(
        fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: AppColors.border,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      iconTheme: const IconThemeData(color: AppColors.muted, size: 22),

      // Navbar web: putih semi-transparan, garis bawah tipis, tanpa bayangan
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        iconTheme: IconThemeData(color: AppColors.ink, size: 24),
        actionsIconTheme: IconThemeData(color: AppColors.ink, size: 22),
      ),

      // Card web: border 1px, radius 16, bayangan sangat tipis
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: AppColors.disabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          textStyle: buttonTextStyle,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: AppColors.disabled,
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          backgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.disabled,
          side: BorderSide(color: AppColors.blue.withValues(alpha: 0.5)),
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 40),
          textStyle: buttonTextStyle,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),

      // Input web: putih, radius 10, border abu tipis, fokus biru
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.blue, 1.5),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 1.5),
        disabledBorder: inputBorder(AppColors.border),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        floatingLabelStyle:
            const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: AppColors.disabled, fontSize: 14),
        helperStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.chipBg,
        selectedColor: AppColors.blueLight,
        secondarySelectedColor: AppColors.blueLight,
        disabledColor: AppColors.chipBg,
        labelStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.ink),
        secondaryLabelStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.blueDark),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        iconTheme: const IconThemeData(size: 16, color: AppColors.muted),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        titleTextStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink),
        contentTextStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            height: 1.45,
            color: AppColors.ink),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.dialog)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: const TextStyle(
            fontFamily: fontFamily, fontSize: 14, color: AppColors.ink),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.blue,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.blue,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.border,
        labelStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        iconColor: AppColors.muted,
        textColor: AppColors.ink,
        titleTextStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.ink),
        subtitleTextStyle: const TextStyle(
            fontFamily: fontFamily, fontSize: 12, color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        iconColor: AppColors.muted,
        collapsedIconColor: AppColors.muted,
        textColor: AppColors.ink,
        collapsedTextColor: AppColors.ink,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        width: 272,
        shape: RoundedRectangleBorder(),
        endShape: RoundedRectangleBorder(),
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.tableHead),
        headingTextStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.5),
        dataTextStyle: const TextStyle(
            fontFamily: fontFamily, fontSize: 14, color: AppColors.ink),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 20,
        headingRowHeight: 44,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
            fontFamily: fontFamily, fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(
            fontFamily: fontFamily, fontSize: 12, color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blue,
        linearTrackColor: AppColors.blueLight,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.blue
                : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.disabled, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.blue
                : AppColors.disabled),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.blue
                : const Color(0xFFD1D5DB)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.blue,
          selectedForegroundColor: Colors.white,
          foregroundColor: AppColors.muted,
          side: const BorderSide(color: AppColors.border),
          textStyle: buttonTextStyle,
        ),
      ),
    );
  }
}
