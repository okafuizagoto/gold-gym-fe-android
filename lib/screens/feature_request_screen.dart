import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/feature_request_model.dart';
import '../services/feature_request_api.dart';
import '../utils/constants.dart';
import '../utils/feature_request_menu_options.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Request Fitur: kotak saran untuk penjual (retail & therapy)/pembeli/
/// staff -- ajukan ide fitur baru, atau laporkan perbaikan pada 1 menu yang
/// sedang dipakai. PRIVATE by design -- setiap akun cuma lihat riwayat
/// MILIKNYA SENDIRI di sini; daftar semua request cuma tampil di menu admin
/// (admin_feature_request_screen.dart). Padanan pages/request-fitur
/// (Next.js).
class FeatureRequestScreen extends StatefulWidget {
  const FeatureRequestScreen({super.key});

  @override
  State<FeatureRequestScreen> createState() => _FeatureRequestScreenState();
}

class _FeatureRequestScreenState extends State<FeatureRequestScreen> {
  final _api = FeatureRequestApi();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _otherMenuController = TextEditingController();

  String _type = FeatureRequestType.fiturBaru;
  String? _selectedMenu;
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
    _otherMenuController.dispose();
    super.dispose();
  }

  // KOREKSI 2026-09-18 (QA audit #1.4): dulu tanpa try/catch -- exception
  // (timeout, dll) bikin `_loadingHistory` tidak pernah kembali false,
  // riwayat macet permanen di spinner.
  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final rows = await _api.listMine();
      if (mounted) setState(() => _history = rows ?? []);
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memuat riwayat request: $e');
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isPerbaikan = _type == FeatureRequestType.perbaikan;
    final menu = isPerbaikan
        ? (_selectedMenu == FeatureRequestMenuOptions.lainnya
            ? _otherMenuController.text.trim()
            : (_selectedMenu ?? ''))
        : null;
    if (isPerbaikan && (menu == null || menu.isEmpty)) {
      Toast.error(context, 'Pilih menu yang ingin dilaporkan');
      return;
    }

    // outcode cuma relevan untuk role SELLER -- dipakai backend untuk
    // resolve kategori PENJUAL_RETAIL vs PENJUAL_THERAPY lewat outlet_type
    // outlet aktif akun ini. Role lain (BUYER/STAFF) tidak pernah punya
    // outlet, jadi tidak perlu dikirim.
    final role = await Storage.get(AppConstants.userRoleKey);
    final outcode = role == AppConstants.roleSeller
        ? await Storage.get(AppConstants.outcode)
        : null;

    setState(() => _saving = true);
    try {
      final response = await _api.create(
        type: _type,
        menu: menu,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        outcode: outcode,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Request berhasil diajukan');
        _formKey.currentState!.reset();
        _titleController.clear();
        _descriptionController.clear();
        _otherMenuController.clear();
        setState(() {
          _type = FeatureRequestType.fiturBaru;
          _selectedMenu = null;
        });
        await _loadHistory();
      } else {
        final body = jsonDecode(response.body);
        Toast.error(
            context, body['error']?.toString() ?? 'Gagal mengajukan request');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal mengajukan request');
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
    final isPerbaikan = _type == FeatureRequestType.perbaikan;
    // Tidak pakai sellerOnly -- BUYER dan STAFF juga wajib bisa mengajukan
    // request fitur (menu ini muncul untuk semua role non-admin).
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Request Fitur'),
        drawer: const AppDrawer(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Ajukan Request Fitur',
                icon: Icons.feedback_outlined,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: FeatureRequestType.fiturBaru,
                            label: Text('Fitur Baru'),
                            icon: Icon(Icons.lightbulb_outline),
                          ),
                          ButtonSegment(
                            value: FeatureRequestType.perbaikan,
                            label: Text('Laporkan Perbaikan'),
                            icon: Icon(Icons.build_outlined),
                          ),
                        ],
                        selected: {_type},
                        onSelectionChanged: (v) =>
                            setState(() => _type = v.first),
                      ),
                      if (isPerbaikan) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedMenu,
                          decoration: const InputDecoration(
                            labelText: 'Menu yang dilaporkan',
                          ),
                          items: FeatureRequestMenuOptions.options
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedMenu = v),
                          validator: (v) =>
                              (isPerbaikan && (v == null || v.isEmpty))
                                  ? 'Menu wajib dipilih'
                                  : null,
                        ),
                        if (_selectedMenu ==
                            FeatureRequestMenuOptions.lainnya) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _otherMenuController,
                            decoration: const InputDecoration(
                              labelText: 'Nama menu lainnya',
                            ),
                            validator: (v) => (isPerbaikan &&
                                    _selectedMenu ==
                                        FeatureRequestMenuOptions.lainnya &&
                                    (v == null || v.trim().isEmpty))
                                ? 'Nama menu wajib diisi'
                                : null,
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Judul',
                          hintText: 'Ringkasan singkat request Anda',
                        ),
                        maxLength: 150,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Judul wajib diisi'
                            : null,
                      ),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi',
                          hintText: 'Jelaskan detail request Anda',
                          alignLabelWithHint: true,
                        ),
                        maxLength: 2000,
                        minLines: 3,
                        maxLines: 6,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Deskripsi wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          child:
                              Text(_saving ? 'Mengirim...' : 'Kirim Request'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Riwayat Request Saya',
                icon: Icons.history,
                child: _loadingHistory
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _history.isEmpty
                        ? const EmptyState(
                            icon: Icons.feedback_outlined,
                            title: 'Belum ada request yang diajukan',
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
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                FeatureRequestType.label(
                                                    r.requestType),
                                                if (r.requestMenu.isNotEmpty)
                                                  r.requestMenu,
                                              ].join(' · '),
                                              style: const TextStyle(
                                                  color: AppColors.muted,
                                                  fontSize: 12),
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
