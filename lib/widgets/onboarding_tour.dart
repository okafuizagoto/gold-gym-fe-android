import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';
import '../services/onboarding_api.dart';
import '../utils/constants.dart';
import '../utils/onboarding_steps.dart';
import '../utils/storage.dart';

/// Panduan tooltip pertama kali per role (2026-10-22, porting dari
/// gold-gym-fe-next-js-ts components/OnboardingTour.tsx) -- menyorot menu
/// drawer ASLI satu-satu (tutorial_coach_mark), bukan layar terpisah.
///
/// Alur: AppBarCustom memanggil [maybeAutoStart] di tiap layar ber-drawer;
/// kalau role ini belum pernah melihat panduan (dicek ke backend, sekali per
/// role per sesi aplikasi), drawer dibuka & [pendingRole] diisi. AppDrawer
/// menjalankan [run] begitu menunya selesai dimuat. Menu "Panduan Penggunaan"
/// di drawer memanggil [run] langsung untuk mengulang tour.
class OnboardingTour {
  OnboardingTour._();

  /// Role yang menunggu tour dijalankan begitu drawer terbuka.
  static String? pendingRole;
  static bool _running = false;
  static final Set<String> _checkedRoles = {};

  /// SELLER / STAFF / BUYER (mode pembeli dihitung BUYER), null untuk ADMIN
  /// -- admin punya Quick Menu Admin sendiri di Dashboard.
  static Future<String?> effectiveRole() async {
    final role = await Storage.get(AppConstants.userRoleKey) ?? '';
    final shopMode = await Storage.get(AppConstants.shopModeKey) ?? '';
    if (role.isEmpty || role == AppConstants.roleAdmin) return null;
    if (role == AppConstants.roleBuyer ||
        shopMode == AppConstants.shopModeBuyer) {
      return onboardingRoleBuyer;
    }
    if (role == AppConstants.roleStaff) return onboardingRoleStaff;
    if (role == AppConstants.roleSeller) return onboardingRoleSeller;
    return null;
  }

  static Future<void> maybeAutoStart(BuildContext context) async {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold == null || !scaffold.hasDrawer) return;
    final role = await effectiveRole();
    if (role == null || _checkedRoles.contains(role)) return;
    _checkedRoles.add(role);
    final seen = await OnboardingApi().isSeen(role);
    if (seen || !context.mounted) return;
    pendingRole = role;
    Scaffold.maybeOf(context)?.openDrawer();
  }

  /// Jalankan tour di drawer yang SEDANG terbuka. [keyFor] = GlobalKey menu
  /// drawer per judul (null / belum ter-render -> langkah itu dilewati).
  static Future<void> run({
    required BuildContext context,
    required String role,
    required bool isTherapy,
    required GlobalKey? Function(String title) keyFor,
  }) async {
    if (_running) return;
    _running = true;
    pendingRole = null;
    try {
      final lang = context.read<LanguageProvider>();
      final steps = onboardingStepsFor(role, isTherapy, lang)
          .where((s) => keyFor(s.menuTitle)?.currentContext != null)
          .toList();

      final start = await _welcomeDialog(context, role, lang);
      if (!start || steps.isEmpty || !context.mounted) {
        await OnboardingApi().markSeen(role);
        return;
      }

      final done = Completer<void>();
      final targets = <TargetFocus>[
        for (var i = 0; i < steps.length; i++)
          TargetFocus(
            identify: steps[i].menuTitle,
            keyTarget: keyFor(steps[i].menuTitle),
            shape: ShapeLightFocus.RRect,
            radius: 10,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                builder: (ctx, controller) => _StepCard(
                  index: i,
                  total: steps.length,
                  title: steps[i].menuTitle,
                  text: steps[i].text,
                  lang: lang,
                  onSkip: controller.skip,
                  onNext: controller.next,
                ),
              ),
            ],
          ),
      ];

      TutorialCoachMark(
        targets: targets,
        hideSkip: true,
        opacityShadow: 0.75,
        paddingFocus: 6,
        disableBackButton: true,
        // menu bisa di luar layar (drawer panjang) -- gulir dulu sebelum disorot
        beforeFocus: (target) async {
          final ctx = keyFor(target.identify as String)?.currentContext;
          if (ctx != null && ctx.mounted) {
            await Scrollable.ensureVisible(ctx,
                duration: const Duration(milliseconds: 250), alignment: 0.35);
          }
        },
        onFinish: () {
          if (!done.isCompleted) done.complete();
        },
        onSkip: () {
          if (!done.isCompleted) done.complete();
          return true;
        },
      ).show(context: context);

      await done.future;
      await OnboardingApi().markSeen(role);
    } finally {
      _running = false;
    }
  }

  static Future<bool> _welcomeDialog(
      BuildContext context, String role, LanguageProvider lang) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.tour_rounded, color: AppColors.blue, size: 36),
        title: Text(lang.get('Welcome!', 'Selamat Datang!')),
        content: Text(onboardingWelcome(role, lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.get('Skip', 'Lewati')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.get('Start', 'Mulai')),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final int total;
  final String title;
  final String text;
  final LanguageProvider lang;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _StepCard({
    required this.index,
    required this.total,
    required this.title,
    required this.text,
    required this.lang,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final last = index == total - 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${index + 1}/$total',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!last)
                TextButton(
                  onPressed: onSkip,
                  child: Text(lang.get('Skip', 'Lewati')),
                ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: onNext,
                child: Text(last
                    ? lang.get('Finish', 'Selesai')
                    : lang.get('Next', 'Lanjut')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
