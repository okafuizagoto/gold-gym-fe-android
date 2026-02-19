import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/language_provider.dart';

class AppBarCustom extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const AppBarCustom({
    super.key,
    required this.title,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        // Language toggle
        Consumer<LanguageProvider>(
          builder: (context, langProvider, child) {
            return IconButton(
              icon: Text(
                langProvider.isEnglish ? 'EN' : 'ID',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: () {
                langProvider.toggleLanguage();
              },
            );
          },
        ),

        // User email
        Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final email = userProvider.user?.email ?? 'Guest';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  email,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 8),
      ],
    );
  }
}
