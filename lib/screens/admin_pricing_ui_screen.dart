import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/subscription_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Layar ADMIN: hide/unhide baris "Marketplace pembeli" & "Booking terapi" di matriks fitur
/// halaman Langganan (default disembunyikan). Murni tampilan; fiturnya tetap berfungsi.
/// Padanan pages/admin-langganan-tampilan/index.tsx (Next.js).
class AdminPricingUiScreen extends StatefulWidget {
  const AdminPricingUiScreen({super.key});

  @override
  State<AdminPricingUiScreen> createState() => _AdminPricingUiScreenState();
}

class _AdminPricingUiScreenState extends State<AdminPricingUiScreen> {
  final _api = SubscriptionApi();
  final Map<String, bool> _flags = {'marketplace': false, 'booking': false};
  bool _loading = true;
  String? _saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lang = context.read<LanguageProvider>();
    try {
      final res = await _api.getPlans();
      if (res.statusCode == 200) {
        final ui = jsonDecode(res.body)['ui'];
        if (mounted && ui is Map) {
          setState(() {
            _flags['marketplace'] = ui['show_marketplace'] == true;
            _flags['booking'] = ui['show_booking'] == true;
          });
        }
      } else if (mounted) {
        Toast.error(context,
            lang.get('Failed to load settings', 'Gagal memuat pengaturan'));
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context,
            lang.get('Failed to load settings', 'Gagal memuat pengaturan'));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String key, bool value) async {
    final lang = context.read<LanguageProvider>();
    setState(() => _saving = key);
    try {
      final res = await _api.adminSetPricingUI({key: value});
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() => _flags[key] = value);
          Toast.success(context, lang.get('Saved', 'Tersimpan'));
        }
      } else {
        String msg = lang.get('Failed to save', 'Gagal menyimpan');
        try {
          msg = jsonDecode(res.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, '${lang.get('Failed', 'Gagal')}: $e');
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final title = lang.get('Subscription Display', 'Tampilan Langganan');
    final rows = [
      ('marketplace', lang.get('Buyer marketplace', 'Marketplace pembeli')),
      ('booking', lang.get('Therapy booking', 'Booking terapi')),
    ];
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: AppBarCustom(title: title),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : PageBody(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      title: title,
                      subtitle: lang.get(
                          'Show/hide rows in the Subscription page (default hidden). Display only; the actual features keep working.',
                          'Tampilkan/sembunyikan baris di halaman Langganan (default disembunyikan). Hanya tampilan; fitur aslinya tetap berfungsi.'),
                      icon: Icons.workspace_premium_outlined,
                    ),
                    SectionCard(
                      title: lang.get('Feature rows', 'Baris fitur'),
                      icon: Icons.tune_rounded,
                      child: Column(
                        children: [
                          for (final (key, label) in rows)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(label),
                              subtitle: Text(_flags[key]!
                                  ? lang.get('Shown', 'Ditampilkan')
                                  : lang.get('Hidden', 'Disembunyikan')),
                              value: _flags[key]!,
                              onChanged: _saving == key
                                  ? null
                                  : (v) => _toggle(key, v),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
