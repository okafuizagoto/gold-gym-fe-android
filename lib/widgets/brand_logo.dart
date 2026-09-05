import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Logo Okejual dalam lingkaran bergradasi (web: AuthCard & Sidebar).
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final imageSize = size * 0.55;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.logoStart, AppColors.logoEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.logoEnd.withValues(alpha: 0.35),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.storefront_rounded,
          size: imageSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
