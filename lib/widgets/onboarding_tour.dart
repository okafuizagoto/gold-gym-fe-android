import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';
import '../services/onboarding_api.dart';
import '../utils/constants.dart';
import '../utils/navigation.dart';
import '../utils/onboarding_steps.dart';
import '../utils/storage.dart';
import 'tour_target.dart';

/// Panduan tooltip pertama kali per role (2026-10-22, diperluas 2026-10-23; porting dari
/// gold-gym-fe-next-js-ts components/OnboardingTour.tsx).
///
/// Tiap langkah menu menyorot menu drawer ASLI; "Lanjut" menutup drawer dan membuka halaman
/// menunya, lalu langkah halaman menyorot tombol penting di sana ([TourTarget]). Sebelum menu
/// berikutnya tour kembali ke layar utama dan membuka drawernya lagi. Langkah yang elemennya tidak
/// ada (menu ditolak owner, tombol belum muncul) dilewati otomatis.
///
/// AppBarCustom memanggil [maybeAutoStart] di tiap layar ber-drawer (cek ke backend sekali per
/// role per sesi aplikasi); menu "Panduan Penggunaan" di drawer memanggil [start] langsung.
class OnboardingTour {
  OnboardingTour._();

  static bool _running = false;
  static final Set<String> _checkedRoles = {};

  /// Diisi AppDrawer yang sedang terbuka: GlobalKey menu drawer per judul (null = belum ter-render).
  static GlobalKey? Function(String title)? drawerKeyFor;

  /// Context AppBarCustom tiap layar ber-drawer (yang terakhir = layar paling atas) -- dipakai
  /// untuk membuka/menutup drawer layar itu dari luar.
  static final List<BuildContext> _scaffoldContexts = [];
  static void registerScaffold(BuildContext c) => _scaffoldContexts.add(c);
  static void unregisterScaffold(BuildContext c) => _scaffoldContexts.remove(c);

  static ScaffoldState? _topScaffold() {
    for (final c in _scaffoldContexts.reversed) {
      if (!c.mounted) continue;
      final s = Scaffold.maybeOf(c);
      if (s != null && s.hasDrawer) return s;
    }
    return null;
  }

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
    // beri jeda supaya layar & menu drawer selesai dimuat dulu
    await Future.delayed(const Duration(milliseconds: 600));
    await start();
  }

  /// Mulai tour untuk role akun yang sedang aktif (abaikan status "sudah dilihat").
  static Future<void> start() async {
    final role = await effectiveRole();
    if (role == null) return;
    await _run(role);
  }

  static Future<void> _delay(int ms) =>
      Future.delayed(Duration(milliseconds: ms));

  static Future<void> _run(String role) async {
    if (_running) return;
    final nav = navigatorKey.currentState;
    final overlay = nav?.overlay;
    if (nav == null || overlay == null) return;
    _running = true;
    var completed = false;
    try {
      final ctx = overlay.context;
      final lang = ctx.read<LanguageProvider>();
      final outletType =
          await Storage.get(AppConstants.outletTypeKey) ?? 'RETAIL';
      final steps = onboardingStepsFor(
          role, outletType == AppConstants.outletTherapy, lang);
      if (await _welcomeDialog(ctx, role, lang)) {
        await _runSteps(nav, ctx, steps, lang);
      }
      completed = true;
    } catch (_) {
      // gagal di tengah jalan: jangan tandai "sudah dilihat" supaya bisa muncul lagi
    } finally {
      await _returnToRoot(nav);
      if (completed) await OnboardingApi().markSeen(role);
      _running = false;
    }
  }

  static Future<void> _runSteps(NavigatorState nav, BuildContext ctx,
      List<OnboardingStep> steps, LanguageProvider lang) async {
    String? current; // rute yang sedang dibuka tour (null = layar utama)
    for (final s in steps) {
      switch (s.kind) {
        case OnboardingStepKind.menu:
          await _returnToRoot(nav);
          current = null;
          final key = await _openDrawerFor(s.menuTitle!);
          if (key == null) {
            await _closeDrawer();
            continue;
          }
          final next = await _coach(
            ctx,
            lang: lang,
            title: s.title,
            text: s.text,
            keyTarget: key,
            alignTop: false,
            beforeFocus: () async {
              final c = key.currentContext;
              if (c != null && c.mounted) {
                await Scrollable.ensureVisible(c,
                    duration: const Duration(milliseconds: 250),
                    alignment: 0.35);
              }
            },
          );
          await _closeDrawer();
          if (!next) return;
          if (s.goto != null) {
            nav.pushNamed(s.goto!);
            current = s.goto;
            await _delay(700);
          }
          break;
        case OnboardingStepKind.page:
          if (s.page != current) continue;
          final tctx = await _waitTarget(s.targetId!, 3500);
          if (tctx == null) continue;
          final box = tctx.findRenderObject();
          if (box is! RenderBox || !box.attached) continue;
          await Scrollable.ensureVisible(tctx,
              duration: const Duration(milliseconds: 200), alignment: 0.4);
          await _delay(350);
          if (!tctx.mounted || !box.attached) continue;
          final offset = box.localToGlobal(Offset.zero);
          final size = box.size;
          final screenH = MediaQuery.of(ctx).size.height;
          final next = await _coach(
            ctx,
            lang: lang,
            title: '',
            text: s.text,
            position: TargetPosition(size, offset),
            alignTop: offset.dy + size.height / 2 > screenH * 0.55,
          );
          if (!next) return;
          if (s.goto != null) {
            nav.pushNamed(s.goto!);
            current = s.goto;
            await _delay(700);
          }
          break;
        case OnboardingStepKind.done:
          await _doneDialog(ctx, s.text, lang);
          break;
      }
    }
  }

  static Future<BuildContext?> _waitTarget(String id, int timeoutMs) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (true) {
      final c = TourTargets.contextOf(id);
      if (c != null) return c;
      if (DateTime.now().isAfter(deadline)) return null;
      await _delay(100);
    }
  }

  static Future<void> _returnToRoot(NavigatorState nav) async {
    if (nav.canPop()) {
      nav.popUntil((r) => r.isFirst);
      await _delay(550);
    }
  }

  static Future<GlobalKey?> _openDrawerFor(String title) async {
    final sc = _topScaffold();
    if (sc == null) return null;
    if (!sc.isDrawerOpen) {
      sc.openDrawer();
      await _delay(450);
    }
    final deadline = DateTime.now().add(const Duration(milliseconds: 2500));
    while (DateTime.now().isBefore(deadline)) {
      final key = drawerKeyFor?.call(title);
      if (key?.currentContext != null) return key;
      await _delay(100);
    }
    return null;
  }

  static Future<void> _closeDrawer() async {
    final sc = _topScaffold();
    if (sc != null && sc.isDrawerOpen) {
      sc.closeDrawer();
      await _delay(400);
    }
  }

  /// Satu coach mark; true = Lanjut, false = Lewati.
  static Future<bool> _coach(
    BuildContext ctx, {
    required LanguageProvider lang,
    required String title,
    required String text,
    GlobalKey? keyTarget,
    TargetPosition? position,
    required bool alignTop,
    Future<void> Function()? beforeFocus,
  }) {
    final done = Completer<bool>();
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: title,
          keyTarget: keyTarget,
          targetPosition: position,
          shape: ShapeLightFocus.RRect,
          radius: 10,
          contents: [
            TargetContent(
              align: alignTop ? ContentAlign.top : ContentAlign.bottom,
              builder: (c, controller) => _StepCard(
                title: title,
                text: text,
                lang: lang,
                onSkip: controller.skip,
                onNext: controller.next,
              ),
            ),
          ],
        ),
      ],
      hideSkip: true,
      opacityShadow: 0.75,
      paddingFocus: 6,
      disableBackButton: true,
      beforeFocus: beforeFocus == null ? null : (_) => beforeFocus(),
      onFinish: () {
        if (!done.isCompleted) done.complete(true);
      },
      onSkip: () {
        if (!done.isCompleted) done.complete(false);
        return true;
      },
    ).show(context: ctx);
    return done.future;
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

  static Future<void> _doneDialog(
      BuildContext context, String text, LanguageProvider lang) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded,
            color: AppColors.successDark, size: 36),
        title: Text(lang.get('All set!', 'Selesai!')),
        content: Text(text),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.get('Finish', 'Selesai')),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final String text;
  final LanguageProvider lang;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _StepCard({
    required this.title,
    required this.text,
    required this.lang,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
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
          if (title.isNotEmpty) ...[
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
          ],
          Text(text,
              style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(lang.get('Skip', 'Lewati')),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: onNext,
                child: Text(lang.get('Next', 'Lanjut')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
