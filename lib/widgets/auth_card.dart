import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import 'brand_logo.dart';

/// Kartu terpusat di atas latar lembut bergradasi -- login, daftar, pilih
/// outlet, dsb. (web: AuthCard). Lebar mengikuti layar: penuh di HP (minus
/// margin), maksimum [maxWidth] di tablet; selalu bisa di-scroll sehingga
/// tidak ada bagian yang terpotong di HP landscape.
class AuthCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final double maxWidth;
  final bool showLogo;

  /// widget di bawah kartu (mis. versi aplikasi)
  final Widget? footer;

  const AuthCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.maxWidth = 420,
    this.showLogo = true,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compact = context.isCompact;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // dua "lampu" gradasi di pojok (web: radial-gradient x2)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1.1, -1.1),
                  radius: 1.1,
                  colors: [
                    AppColors.blue.withValues(alpha: 0.18),
                    AppColors.blue.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.1, 1.1),
                  radius: 1.0,
                  colors: [
                    AppColors.teal.withValues(alpha: 0.25),
                    AppColors.teal.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 16 : 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF101828)
                                  .withValues(alpha: 0.10),
                              blurRadius: 60,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(compact ? 24 : 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showLogo) ...[
                              const Center(child: BrandLogo(size: 84)),
                              const SizedBox(height: 10),
                              Text(
                                AppConstants.appName,
                                textAlign: TextAlign.center,
                                style: textTheme.titleLarge?.copyWith(
                                  color: AppColors.blue,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                            if (title != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                title!,
                                textAlign: TextAlign.center,
                                style: textTheme.headlineSmall,
                              ),
                            ],
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ],
                            const SizedBox(height: 24),
                            child,
                          ],
                        ),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 16),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
