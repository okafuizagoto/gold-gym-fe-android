import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/feature_request_model.dart';
import '../providers/language_provider.dart';
import '../services/feature_request_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Request Aplikasi Baru: kotak saran untuk penjual (retail & therapy)/
/// pembeli/staff -- ajukan ide APLIKASI terpisah (bukan fitur di dalam
/// Okejual), mis. "aplikasi kas harian". Memakai infrastruktur yang sama
/// dengan feature_request_screen.dart (tabel & API feature_requests,
/// request_type = APLIKASI_BARU), cuma menu/layar terpisah supaya tidak
/// tercampur dengan ide fitur Okejual sendiri. PRIVATE by design -- setiap
/// akun cuma lihat riwayat MILIKNYA SENDIRI di sini; daftar semua request
/// cuma tampil di menu admin (admin_feature_request_screen.dart, filter
/// tipe "Aplikasi Baru"). Bilingual (LanguageProvider) -- padanan
/// pages/request-aplikasi-baru (Next.js), ubah keduanya bersamaan (termasuk
/// teksnya).
class AppRequestScreen extends StatefulWidget {
  const AppRequestScreen({super.key});

  @override
  State<AppRequestScreen> createState() => _AppRequestScreenState();
}

class _AppRequestScreenState extends State<AppRequestScreen> {
  final _api = FeatureRequestApi();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _saving = false;
  bool _loadingHistory = true;
  List<FeatureRequest> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final rows = await _api.listMine();
      // listMine mengembalikan SEMUA tipe request milik akun ini -- saring
      // khusus aplikasi baru supaya tidak tercampur dengan riwayat Request Fitur.
      if (mounted) {
        setState(() => _history = (rows ?? [])
            .where((r) => r.requestType == FeatureRequestType.aplikasiBaru)
            .toList());
      }
    } catch (e) {
      if (mounted) {
        final lang = context.read<LanguageProvider>();
        Toast.error(context,
            '${lang.get("Failed to load request history", "Gagal memuat riwayat request")}: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final lang = context.read<LanguageProvider>();

    final role = await Storage.get(AppConstants.userRoleKey);
    final outcode = role == AppConstants.roleSeller
        ? await Storage.get(AppConstants.outcode)
        : null;

    setState(() => _saving = true);
    try {
      final response = await _api.create(
        type: FeatureRequestType.aplikasiBaru,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        outcode: outcode,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(
            context,
            lang.get('App request sent, thank you!',
                'Request aplikasi berhasil diajukan'));
        _formKey.currentState!.reset();
        _titleController.clear();
        _descriptionController.clear();
        await _loadHistory();
      } else {
        final body = jsonDecode(response.body);
        Toast.error(
            context,
            body['error']?.toString() ??
                lang.get(
                    'Failed to send app request', 'Gagal mengajukan request'));
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context,
            lang.get('Failed to send app request', 'Gagal mengajukan request'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case FeatureRequestStatus.ditinjau:
        return AppColors.info;
      case FeatureRequestStatus.direncanakan:
        return AppColors.warning;
      case FeatureRequestStatus.selesai:
        return AppColors.success;
      case FeatureRequestStatus.ditolak:
        return AppColors.error;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    // Tidak pakai sellerOnly -- BUYER dan STAFF juga wajib bisa mengajukan
    // request aplikasi (menu ini muncul untuk semua role non-admin).
    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
            title: lang.get('Request New App', 'Request Aplikasi Baru')),
        drawer: const AppDrawer(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: lang.get('Submit an App Idea', 'Ajukan Ide Aplikasi'),
                icon: Icons.apps_outlined,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText:
                              lang.get('App name/title', 'Nama/judul aplikasi'),
                          hintText: lang.get('A short summary of your idea',
                              'Ringkasan singkat idenya'),
                        ),
                        maxLength: 150,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? lang.get('Title is required', 'Judul wajib diisi')
                            : null,
                      ),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: lang.get('Tell us what the app is for',
                              'Ceritakan aplikasinya untuk apa'),
                          hintText: lang.get(
                              'Example: an app for tracking daily cash in/out outside the store',
                              'Contoh: aplikasi pencatatan uang masuk/keluar harian di luar toko'),
                          alignLabelWithHint: true,
                        ),
                        maxLength: 2000,
                        minLines: 3,
                        maxLines: 6,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? lang.get('Description is required',
                                'Deskripsi wajib diisi')
                            : null,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          child: Text(_saving
                              ? lang.get('Sending...', 'Mengirim...')
                              : lang.get('Send Request', 'Kirim Request')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: lang.get('My Requests', 'Riwayat Request Saya'),
                icon: Icons.history,
                child: _loadingHistory
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _history.isEmpty
                        ? EmptyState(
                            icon: Icons.apps_outlined,
                            title: lang.get('No requests submitted yet',
                                'Belum ada request yang diajukan'),
                            compact: true,
                          )
                        : Column(
                            children: _history
                                .map((r) => Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(r.requestTitle,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                                Chip(
                                                  label: Text(
                                                    FeatureRequestStatus.label(
                                                        r.requestStatus),
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11),
                                                  ),
                                                  backgroundColor: _statusColor(
                                                      r.requestStatus),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(r.requestDescription),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
