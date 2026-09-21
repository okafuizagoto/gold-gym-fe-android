import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/play_billing.dart';
import '../services/subscription_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/subscription_state.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Layar Langganan: status paket, batas pemakaian, dan perbandingan paket.
/// Padanan pages/langganan/index.tsx (Next.js) -- ubah keduanya bersamaan.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionInfo? _sub;
  List<PlanDef> _plans = const [];
  bool _yearly = false;
  bool _isStaff = false;
  bool _loading = true;
  bool _buying = false;
  String _focusFeature = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // fitur yang mengarahkan ke layar ini (dari menu terkunci)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _focusFeature = args;
    }
  }

  Future<void> _load() async {
    final cached = await SubscriptionState.load();
    final role = await Storage.get(AppConstants.userRoleKey);
    if (mounted) {
      setState(() {
        _sub = cached;
        _isStaff = role == AppConstants.roleStaff;
      });
    }
    final fresh = await SubscriptionState.refresh();
    try {
      final res = await SubscriptionApi().getPlans();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body is Map ? body['data'] : null;
        if (list is List) {
          _plans = list
              .whereType<Map<String, dynamic>>()
              .map(PlanDef.fromJson)
              .toList();
        }
      } else if (mounted) {
        Toast.error(context, 'Gagal memuat daftar paket');
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context,
            'Gagal memuat daftar paket. Periksa koneksi internet Anda.');
      }
    }
    if (!mounted) return;
    setState(() {
      _sub = fresh ?? _sub;
      _loading = false;
    });
  }

  double get _ringValue {
    final s = _sub;
    if (s == null || s.readOnly) return 0;
    if (s.status == 'LIFETIME' || s.daysLeft == null) return 1;
    final total =
        s.status == 'TRIAL' ? (s.trialDays == 0 ? 15 : s.trialDays) : 30;
    return (s.daysLeft! / total).clamp(0.0, 1.0);
  }

  Color get _ringColor {
    final s = _sub;
    if (s == null) return AppColors.blue;
    if (s.readOnly) return AppColors.error;
    if (s.status != 'LIFETIME' && (s.daysLeft ?? 99) <= 3) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  String _statusSentence(SubscriptionInfo s) {
    if (s.readOnly) {
      return 'Berakhir pada ${formatDate(s.periodEnd)}. Aplikasi dalam mode baca saja.';
    }
    switch (s.status) {
      case 'LIFETIME':
        return 'Tidak ada batas waktu.';
      case 'TRIAL':
        return 'Percobaan gratis sampai ${formatDate(s.periodEnd)}, dengan fitur paket tertinggi.';
      default:
        return 'Berlaku sampai ${formatDate(s.periodEnd)}.';
    }
  }

  /// Langganan aktif lewat sumber lain (web/admin): pembelian Play dinonaktifkan supaya tidak
  /// ada dua langganan berbayar sekaligus.
  bool get _activeElsewhere {
    final s = _sub;
    return s != null &&
        !s.readOnly &&
        s.status == 'ACTIVE' &&
        s.source != 'PLAY';
  }

  Future<void> _buyWithPlay(PlanDef p) async {
    setState(() => _buying = true);
    final r = await PlayBilling.instance.purchase(p.id, yearly: _yearly);
    await _afterPlay(r);
  }

  Future<void> _restorePlay() async {
    setState(() => _buying = true);
    final r = await PlayBilling.instance.restore();
    await _afterPlay(r);
  }

  Future<void> _afterPlay(PlayResult r) async {
    if (r.outcome == PlayOutcome.success) {
      await SubscriptionState.refresh();
    }
    if (!mounted) return;
    setState(() => _buying = false);
    if (r.outcome == PlayOutcome.success) {
      Toast.success(
          context, r.message.isEmpty ? 'Langganan aktif.' : r.message);
      await _load();
    } else if (r.outcome != PlayOutcome.cancelled || r.message.isNotEmpty) {
      if (r.message.isNotEmpty) Toast.info(context, r.message);
    }
  }

  Future<void> _openPlaySubscriptions() async {
    await launchUrl(
      Uri.parse('https://play.google.com/store/account/subscriptions'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _askPlan(PlanDef p) {
    // Di aplikasi Android (Play Store) pembelian HANYA lewat Google Play Billing -- kebijakan
    // Google melarang mengarahkan pengguna ke pembayaran di luar Play.
    if (PlayBilling.supported) {
      _buyWithPlay(p);
      return;
    }
    final price = _yearly ? p.priceYearly : p.priceMonthly;
    showDialog<void>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text('Berlangganan paket ${p.name}'),
        content: Text(
          'Pembayaran langganan langsung dari aplikasi segera hadir. Untuk saat ini, '
          'hubungi admin Okejual agar paket ${p.name} (${formatRupiah(price)}/${_yearly ? 'tahun' : 'bulan'}) '
          'diaktifkan di akun Anda.\n\nEmail: admin@okejual.co.id',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: const Text('Mengerti')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = _sub;
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Langganan'),
        drawer: const AppDrawer(),
        body: PageBody(
          maxWidth: 900,
          child: ListView(
            children: [
              if (_focusFeature.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      'Fitur ${featureLabel(_focusFeature)} tersedia di paket yang lebih tinggi.'),
                ),
              // ---- Status ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: s == null
                      ? Center(
                          child: _loading
                              ? const CircularProgressIndicator()
                              : const Text('Status langganan belum tersedia.'))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 96,
                              height: 96,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: 1,
                                      strokeWidth: 8,
                                      color: AppColors.border,
                                    ),
                                  ),
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: _ringValue,
                                      strokeWidth: 8,
                                      color: _ringColor,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s.readOnly
                                            ? '0'
                                            : (s.daysLeft?.toString() ?? '∞'),
                                        style: textTheme.headlineSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                      Text('hari',
                                          style: textTheme.bodySmall?.copyWith(
                                              color: AppColors.muted)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text('Paket ${s.planName}',
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w800)),
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          const {
                                                'TRIAL': 'Masa percobaan',
                                                'ACTIVE': 'Aktif',
                                                'LIFETIME':
                                                    'Aktif tanpa batas waktu',
                                                'EXPIRED': 'Berakhir',
                                              }[s.status] ??
                                              s.status,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_statusSentence(s),
                                      style: textTheme.bodyMedium
                                          ?.copyWith(color: AppColors.muted)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _pill(Icons.storefront_rounded,
                                          formatLimit(s.maxOutlets, 'outlet')),
                                      _pill(
                                        Icons.groups_rounded,
                                        s.maxUsers < 0
                                            ? '${s.usersUsed} pengguna terpakai (tak terbatas)'
                                            : '${s.usersUsed} dari ${s.maxUsers} pengguna',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              // ---- Paket ----
              Row(
                children: [
                  Expanded(
                    child: Text('Pilih paket',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  ChoiceChip(
                    label: const Text('Bulanan'),
                    selected: !_yearly,
                    onSelected: (_) => setState(() => _yearly = false),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Tahunan · hemat 2 bulan'),
                    selected: _yearly,
                    onSelected: (_) => setState(() => _yearly = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final p in _plans) _planCard(p, textTheme),
              if (s != null && _plans.isNotEmpty) _missingBanner(s),
              if (PlayBilling.supported && !_isStaff)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _buying ? null : _restorePlay,
                      child: const Text('Pulihkan pembelian'),
                    ),
                    if (s?.source == 'PLAY')
                      TextButton(
                        onPressed: _openPlaySubscriptions,
                        child: const Text('Kelola di Google Play'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: AppColors.blueDark),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppColors.blueLight,
      side: BorderSide.none,
    );
  }

  Widget _planCard(PlanDef p, TextTheme textTheme) {
    final s = _sub;
    final current =
        s != null && s.plan == p.id && s.status != 'TRIAL' && !s.readOnly;
    final recommended = p.id == 'growth';
    final price = _yearly ? p.priceYearly : p.priceMonthly;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          width: current || recommended ? 2 : 1,
          color: current
              ? AppColors.success
              : recommended
                  ? AppColors.blue
                  : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.name,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (current)
                  const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('Paket Anda'))
                else if (recommended)
                  const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('Direkomendasikan')),
              ],
            ),
            RichText(
              text: TextSpan(
                style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: AppColors.ink),
                children: [
                  TextSpan(text: formatRupiah(price)),
                  TextSpan(
                    text: ' /${_yearly ? 'tahun' : 'bulan'}',
                    style:
                        textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (_yearly)
              Text('setara ${formatRupiah((p.priceYearly / 12).round())}/bulan',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _pill(Icons.storefront_rounded,
                    formatLimit(p.maxOutlets, 'outlet')),
                _pill(
                  Icons.groups_rounded,
                  p.maxUsers < 0
                      ? 'Pengguna tak terbatas'
                      : p.maxUsers == 1
                          ? 'Pemilik saja'
                          : '${p.maxUsers} pengguna',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: recommended
                  ? FilledButton(
                      onPressed: _canBuy(current) ? () => _askPlan(p) : null,
                      child: Text(_btnText(p, current)),
                    )
                  : OutlinedButton(
                      onPressed: _canBuy(current) ? () => _askPlan(p) : null,
                      child: Text(_btnText(p, current)),
                    ),
            ),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Lihat semua fitur',
                    style: TextStyle(fontSize: 14)),
                children: [
                  for (final f in p.features)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 18, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              featureLabel(f),
                              style: TextStyle(
                                  fontWeight: f == _focusFeature
                                      ? FontWeight.w700
                                      : FontWeight.w400),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canBuy(bool current) {
    if (current || _isStaff || _buying) return false;
    if (PlayBilling.supported && _activeElsewhere) return false;
    return true;
  }

  String _btnText(PlanDef p, bool current) {
    if (current) return 'Paket saat ini';
    if (_isStaff) return 'Hubungi pemilik';
    if (_buying) return 'Memproses...';
    if (PlayBilling.supported && _activeElsewhere) {
      return 'Langganan sedang aktif';
    }
    return 'Pilih ${p.name}';
  }

  Widget _missingBanner(SubscriptionInfo s) {
    PlanDef? top;
    for (final p in _plans) {
      if (p.id == 'pro') top = p;
    }
    final missing = (top?.features ?? const <String>[])
        .where((f) => !s.features.contains(f))
        .map(featureLabel)
        .toList();
    if (missing.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_rounded,
              size: 18, color: AppColors.warningDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Belum termasuk di paket Anda: ${missing.join(', ')}.'),
          ),
        ],
      ),
    );
  }
}
