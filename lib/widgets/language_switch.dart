import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';

/// Saklar bahasa 🇮🇩 ID / 🇬🇧 EN (dipakai di layar daftar akun dan kartu panduan). Pilihan diingat di perangkat.
class LanguageSwitch extends StatelessWidget {
  final MainAxisAlignment alignment;
  const LanguageSwitch({super.key, this.alignment = MainAxisAlignment.end});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        TextButton(
          onPressed: () => lang.setLanguage('ID'),
          child: Text('🇮🇩 ID',
              style: TextStyle(
                  fontWeight:
                      lang.isIndonesian ? FontWeight.bold : FontWeight.normal)),
        ),
        const Text('/', style: TextStyle(color: AppColors.disabled)),
        TextButton(
          onPressed: () => lang.setLanguage('EN'),
          child: Text('🇬🇧 EN',
              style: TextStyle(
                  fontWeight:
                      lang.isEnglish ? FontWeight.bold : FontWeight.normal)),
        ),
      ],
    );
  }
}
