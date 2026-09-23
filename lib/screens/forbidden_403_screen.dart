import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../utils/responsive.dart';
import '../widgets/private_route.dart';
import '../providers/language_provider.dart';

class Forbidden403Screen extends StatelessWidget {
  const Forbidden403Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          final textTheme = Theme.of(context).textTheme;
          return Scaffold(
            appBar: AppBar(
              title: Text(langProvider.get('Access Denied', 'Akses Ditolak')),
            ),
            body: PageBody(
              maxWidth: 480,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    vertical: context.isShort ? 8 : 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.errorLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        size: 52,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '403',
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 40,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      langProvider.get('Access Denied', 'Akses Ditolak'),
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      langProvider.get(
                        'You do not have permission to access this page',
                        'Anda tidak memiliki izin untuk mengakses halaman ini',
                      ),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
                      icon: const Icon(Icons.home_rounded, size: 20),
                      label: Text(
                        langProvider.get('Go to Home', 'Ke Halaman Utama'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
