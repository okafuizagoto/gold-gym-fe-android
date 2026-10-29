import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';
import '../services/onboarding_api.dart';
import '../services/outlet_api.dart';
import '../utils/constants.dart';
import '../utils/navigation.dart';
import '../utils/onboarding_steps.dart';
import '../utils/seller_outlet_gate.dart';
import '../utils/storage.dart';
import 'language_switch.dart';
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
  // Diulang manual lewat "Panduan Penggunaan" -> tombol Lewati tampil (panduan pertama wajib diselesaikan).
  static bool _replay = false;
  static final Set<String> _checkedRoles = {};

  // Penutup layar transparan selama tour (juga di jeda antar langkah, saat drawer/halaman berpindah):
  // semua sentuhan di bawahnya dibuang, hanya coach mark & dialog tour (di-insert SETELAH ini, jadi di atasnya)
  // yang bisa disentuh. Wajib di-raise lagi setelah halaman baru di-push, karena route baru masuk ke overlay
  // di atasnya.
  static OverlayEntry? _blocker;
  static void _raiseBlocker(OverlayState overlay) {
    _blocker?.remove();
    _blocker = OverlayEntry(
      builder: (_) => const Positioned.fill(
        child: ModalBarrier(dismissible: false, color: Colors.transparent),
      ),
    );
    overlay.insert(_blocker!);
  }

  static void _removeBlocker() {
    _blocker?.remove();
    _blocker = null;
  }

  /// Diisi AppDrawer yang sedang terbuka: GlobalKey menu drawer per judul (null = belum ter-render).
  static GlobalKey? Function(String title)? drawerKeyFor;

  /// Context AppBarCustom tiap layar ber-drawer (yang terakhir = layar paling atas) -- dipakai
  /// untuk membuka/menutup drawer layar itu dari luar.
  static final List<BuildContext> _scaffoldContexts = [];
  static void registerScaffold(BuildContext c) => _scaffoldContexts.add(c);
  static void unregisterScaffold(BuildContext c) => _scaffoldContexts.remove(c);

  /// Context layar paling atas yang berada DI DALAM Overlay navigator. TutorialCoachMark.show() memanggil
  /// Overlay.of(context), yang mencari ke leluhur -- context milik OverlayState sendiri (nav.overlay.context)
  /// TIDAK menemukan overlay dan melempar error (diuji di emulator 2026-10-23: coach mark tidak pernah muncul).
  static BuildContext? _liveContext() {
    for (final c in _scaffoldContexts.reversed) {
      if (c.mounted) return c;
    }
    return null;
  }

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
    await start(manual: false);
  }

  /// Mulai tour untuk role akun yang sedang aktif (abaikan status "sudah dilihat").
  static Future<void> start({bool manual = true}) async {
    final role = await effectiveRole();
    if (role == null) return;
    await _run(role, manual);
  }

  /// Kode outlet dummy dari respons dummyensure ({"data":{"outlet_code":"ADM-..."}}); null kalau tidak ada.
  static String? _dummyCodeFrom(String body) {
    try {
      final data = (jsonDecode(body) as Map<String, dynamic>)['data'];
      final code = data is Map ? data['outlet_code'] : null;
      return code is String && code.startsWith('ADM-') ? code : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _delay(int ms) =>
      Future.delayed(Duration(milliseconds: ms));

  static Future<void> _run(String role, bool manual) async {
    if (_running) return;
    _replay = manual;
    final nav = navigatorKey.currentState;
    final overlay = nav?.overlay;
    if (nav == null || overlay == null) return;
    _running = true;
    var completed = false;
    String? dummyCode; // kode outlet dummy yang dipilih sementara selama panduan pertama
    try {
      final ctx = overlay.context;
      final lang = ctx.read<LanguageProvider>();
      final outletType =
          await Storage.get(AppConstants.outletTypeKey) ?? 'RETAIL';
      // Teks langkah dihitung ULANG tiap langkah (lihat _runSteps) supaya mengganti bahasa di tengah panduan
      // langsung berlaku di langkah berikutnya.
      List<OnboardingStep> stepsFn() => onboardingStepsFor(
          role, outletType == AppConstants.outletTherapy, lang);
      if (await _welcomeDialog(ctx, role, lang)) {
        // Dialog (route) disisipkan Navigator DI BAWAH penutup ini, jadi penutup hanya dipasang di antara
        // dialog: selama dialog tampil, dialognya sendiri sudah modal. Coach mark (OverlayEntry) tetap di atasnya.
        _raiseBlocker(overlay);
        // Penjual baru (belum punya outlet asli) dapat outlet dummy supaya tombol seperti ANTRIAN bisa
        // disorot; backend tidak membuat apa pun untuk penjual yang sudah punya outlet. Gagal = tanpa dummy.
        // HANYA panduan pertama setelah buat akun (bukan ulang lewat menu Panduan Penggunaan): backend mengisi
        // outlet dummy itu dengan data contoh (area/meja, barang, nota, antrean, staff) supaya langkah yang
        // menyorot isi halaman punya sasaran, dan outlet dummy dipilih sementara supaya halaman membacanya.
        if (role == onboardingRoleSeller && !manual) {
          try {
            final resp = await OutletsApi().ensureDummyOutlet();
            final code = _dummyCodeFrom(resp.body);
            if (resp.statusCode == 200 && code != null) {
              dummyCode = code;
              await Storage.set(AppConstants.outcode, code);
              await Storage.set(AppConstants.outletTypeKey, 'RETAIL');
            }
          } catch (_) {}
        }
        await _runSteps(nav, ctx, stepsFn, lang);
      }
      completed = true;
    } catch (e, st) {
      // gagal di tengah jalan: jangan tandai "sudah dilihat" supaya bisa muncul lagi
      debugPrint('[OnboardingTour] gagal: $e\n$st');
    } finally {
      // Penutup layar tetap terpasang sampai SEMUA pembersihan di bawah selesai (tidak ada celah sentuh).
      _raiseBlocker(overlay);
      await _closeDrawer();
      await _returnToRoot(nav);
      if (role == onboardingRoleSeller) {
        // Lepas pilihan outlet dummy dulu (hanya kalau memang masih dummy tadi), lalu hapus outlet + data contohnya.
        if (dummyCode != null &&
            await Storage.get(AppConstants.outcode) == dummyCode) {
          await Storage.delete(AppConstants.outcode);
          await Storage.delete(AppConstants.outletTypeKey);
        }
        // Penjual: buang outlet dummy panduan. Kalau tetap belum punya outlet asli, wajib membuatnya dulu:
        // arahkan ke /outlet (hanya NEW OUTLET dan LOGOUT yang aktif).
        try {
          await OutletsApi().clearDummyOutlet();
        } catch (_) {}
      }
      if (completed) await OnboardingApi().markSeen(role);
      if (role == onboardingRoleSeller &&
          await SellerOutletGate.realOutletCount() == 0) {
        nav.pushNamedAndRemoveUntil('/outlet', (route) => false);
      }
      _removeBlocker();
      _running = false;
    }
  }

  static Future<void> _runSteps(NavigatorState nav, BuildContext ctx,
      List<OnboardingStep> Function() stepsFn, LanguageProvider lang) async {
    final total = stepsFn().length;
    String? current; // rute yang sedang dibuka tour (null = layar utama)
    // Langkah yang dilewati (target tidak ada, mis. outlet baru belum punya nota) tidak dihitung supaya penghitung
    // tetap berurutan (1/N, 2/N, ...) dan N menyusut sesuai langkah yang benar-benar ditampilkan.
    var skipped = 0;
    for (var idx = 0; idx < total; idx++) {
      final s = stepsFn()[idx];
      final progress = '${idx + 1 - skipped}/${total - skipped}';
      switch (s.kind) {
        case OnboardingStepKind.menu:
          await _returnToRoot(nav);
          current = null;
          final key = await _openDrawerFor(s.menuTitle!);
          if (key == null) {
            await _closeDrawer();
            skipped++;
            continue;
          }
          final host = _liveContext();
          if (host == null) {
            await _closeDrawer();
            skipped++;
            continue;
          }
          final next = await _coach(
            host,
            lang: lang,
            title: s.title,
            text: s.text,
            keyTarget: key,
            progress: progress,
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
            await _delay(60);
            _raiseBlocker(nav.overlay!);
            await _delay(640);
            _raiseBlocker(nav.overlay!);
          }
          break;
        case OnboardingStepKind.page:
          if (s.page != current) {
            skipped++;
            continue;
          }
          final tctx = await _waitTarget(s.targetId!, 3500);
          if (tctx == null) {
            skipped++;
            continue;
          }
          final box = tctx.findRenderObject();
          if (box is! RenderBox || !box.attached) {
            skipped++;
            continue;
          }
          await Scrollable.ensureVisible(tctx,
              duration: const Duration(milliseconds: 200), alignment: 0.4);
          // Tunggu posisi benar-benar diam (transisi halaman/gulir/animasi masuk selesai) -- membaca posisi
          // di tengah animasi membuat sorotan meleset (terlihat di emulator 2026-10-23).
          final rect = await _stableRect(tctx);
          if (rect == null) {
            skipped++;
            continue;
          }
          final offset = rect.$1;
          final size = rect.$2;
          final screenH = MediaQuery.of(ctx).size.height;
          final next = await _coach(
            tctx, // context target = di dalam Overlay layar ini
            lang: lang,
            title: '',
            text: s.text,
            position: TargetPosition(size, offset),
            progress: progress,
            alignTop: offset.dy + size.height / 2 > screenH * 0.55,
          );
          if (!next) return;
          if (s.goto != null) {
            nav.pushNamed(s.goto!);
            current = s.goto;
            await _delay(60);
            _raiseBlocker(nav.overlay!);
            await _delay(640);
            _raiseBlocker(nav.overlay!);
          }
          break;
        case OnboardingStepKind.done:
          _removeBlocker(); // lihat catatan di _run: dialog tidak boleh berada di bawah penutup
          await _doneDialog(ctx, s.text, lang, progress);
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

  /// Posisi global + ukuran target setelah tidak berubah selama 3 pembacaan berturut-turut (100 ms/pembacaan),
  /// maksimal ~3 detik; null kalau target hilang.
  static Future<(Offset, Size)?> _stableRect(BuildContext c) async {
    Offset? last;
    Size? lastSize;
    var stable = 0;
    (Offset, Size)? latest;
    for (var i = 0; i < 30; i++) {
      if (!c.mounted) return null;
      final box = c.findRenderObject();
      if (box is! RenderBox || !box.attached) return null;
      final o = box.localToGlobal(Offset.zero);
      final sz = box.size;
      latest = (o, sz);
      if (last != null && (o - last).distanceSquared < 1 && sz == lastSize) {
        if (++stable >= 3) return latest;
      } else {
        stable = 0;
      }
      last = o;
      lastSize = sz;
      await _delay(100);
    }
    return latest;
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
    BuildContext host, {
    required LanguageProvider lang,
    required String title,
    required String text,
    required String progress,
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
          // hanya tombol Lanjut yang boleh ditekan: menyentuh elemen yang disorot tidak melakukan apa pun
          enableTargetTab: false,
          enableOverlayTab: false,
          contents: [
            TargetContent(
              align: alignTop ? ContentAlign.top : ContentAlign.bottom,
              builder: (c, controller) => _StepCard(
                title: title,
                text: text,
                lang: lang,
                progress: progress,
                showSkip: _replay,
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
    ).show(context: host);
    return done.future;
  }

  static Future<bool> _welcomeDialog(
      BuildContext context, String role, LanguageProvider lang) async {
    // Panduan pertama wajib diselesaikan: tanpa Lewati dan tombol Back sistem dimatikan (replay boleh).
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer<LanguageProvider>(
        builder: (ctx, lang, _) => PopScope(
        canPop: _replay,
        child: AlertDialog(
          icon: const Icon(Icons.tour_rounded, color: AppColors.blue, size: 36),
          title: Text(lang.get('Welcome!', 'Selamat Datang!')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(onboardingWelcome(role, lang)),
              const SizedBox(height: 8),
              const Align(alignment: Alignment.centerRight, child: LanguageSwitch()),
            ],
          ),
          actions: [
            if (_replay)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(lang.get('Skip', 'Lewati')),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(lang.get('Next', 'Lanjut')),
            ),
          ],
        ),
      ),
      ),
    );
    return result == true;
  }

  static Future<void> _doneDialog(BuildContext context, String text,
      LanguageProvider lang, String progress) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.successDark, size: 36),
          title: Text(lang.get('All set!', 'Selesai!')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text(text)],
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(lang.get('Finish', 'Selesai')),
                ),
                const SizedBox(height: 6),
                Text(progress,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final String text;
  final LanguageProvider lang;
  final String progress;
  final bool showSkip;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _StepCard({
    required this.title,
    required this.text,
    required this.lang,
    required this.progress,
    required this.showSkip,
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
              // Tombol bahasa tetap bisa dipakai selama panduan (layar di bawahnya dikunci, kartu ini tidak)
              const LanguageSwitch(),
              const Spacer(),
              if (showSkip) ...[
                TextButton(
                  onPressed: onSkip,
                  child: Text(lang.get('Skip', 'Lewati')),
                ),
                const SizedBox(width: 6),
              ],
              ElevatedButton(
                onPressed: onNext,
                child: Text(lang.get('Next', 'Lanjut')),
              ),
            ],
          ),
          // Penghitung langkah (sama dengan web): 1/30, 2/30, ...
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(progress,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}
