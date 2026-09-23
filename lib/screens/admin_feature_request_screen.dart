import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/feature_request_model.dart';
import '../services/api_client.dart';
import '../services/feature_request_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Admin: daftar SEMUA request fitur/perbaikan dari penjual (retail &
/// therapy)/pembeli/staff, dengan filter kategori/status/tipe dan aksi ubah
/// status. Sama seperti admin_storage_usage_screen.dart, gating admin-only
/// cukup lewat drawer (grup "Akses Admin") + backend 403 -- tidak ada
/// pengecekan role tambahan di client. Padanan pages/admin-request-fitur
/// (Next.js).
class AdminFeatureRequestScreen extends StatefulWidget {
  const AdminFeatureRequestScreen({super.key});

  @override
  State<AdminFeatureRequestScreen> createState() =>
      _AdminFeatureRequestScreenState();
}

class _AdminFeatureRequestScreenState extends State<AdminFeatureRequestScreen> {
  final _api = FeatureRequestApi();
  bool _loading = true;
  bool _forbidden = false;
  List<FeatureRequest> _rows = [];

  String? _category;
  String? _status;
  String? _type;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // KOREKSI 2026-09-18 (QA audit #1.4): dulu tanpa try/catch dan `rows==
  // null` disamakan dengan "forbidden" utk SEMUA error -- exception juga
  // bikin seluruh layar (termasuk filter) macet permanen di spinner.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _api.adminListAll(
          category: _category, status: _status, type: _type);
      if (mounted) {
        setState(() {
          _rows = rows;
          _forbidden = false;
        });
      }
    } on ForbiddenException {
      if (mounted) setState(() => _forbidden = true);
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memuat daftar request: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // KOREKSI 2026-09-18 (QA audit #1.5): dulu tanpa try/catch di sekeliling
  // PATCH -- kalau timeout, exception ditangkap default Zone handler
  // (console saja), popup tertutup TANPA toast, admin tidak sadar aksinya
  // gagal.
  Future<void> _changeStatus(FeatureRequest r, String status) async {
    try {
      final resp = await _api.adminUpdateStatus(r.requestId, status);
      if (resp.statusCode == 200) {
        if (mounted) {
          Toast.success(context,
              'Status diubah ke ${FeatureRequestStatus.label(status)}');
        }
        await _load();
      } else {
        if (mounted) Toast.error(context, 'Gagal mengubah status');
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal mengubah status: $e');
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
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Daftar Request Fitur'),
        drawer: const AppDrawer(),
        body: _forbidden
            ? const EmptyState(
                icon: Icons.feedback_outlined, title: 'Khusus admin')
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SectionCard(
                          title: 'Filter',
                          icon: Icons.filter_alt_outlined,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _category,
                                  decoration: const InputDecoration(
                                      labelText: 'Kategori'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null, child: Text('Semua')),
                                    ...FeatureRequestCategory.all.map((c) =>
                                        DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                                FeatureRequestCategory.label(
                                                    c)))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _category = v);
                                    _load();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _status,
                                  decoration: const InputDecoration(
                                      labelText: 'Status'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null, child: Text('Semua')),
                                    ...FeatureRequestStatus.all.map((s) =>
                                        DropdownMenuItem(
                                            value: s,
                                            child: Text(
                                                FeatureRequestStatus.label(
                                                    s)))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _status = v);
                                    _load();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _type,
                                  decoration:
                                      const InputDecoration(labelText: 'Tipe'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null, child: Text('Semua')),
                                    DropdownMenuItem(
                                        value: FeatureRequestType.fiturBaru,
                                        child: Text(FeatureRequestType.label(
                                            FeatureRequestType.fiturBaru))),
                                    DropdownMenuItem(
                                        value: FeatureRequestType.perbaikan,
                                        child: Text(FeatureRequestType.label(
                                            FeatureRequestType.perbaikan))),
                                    DropdownMenuItem(
                                        value: FeatureRequestType.aplikasiBaru,
                                        child: Text(FeatureRequestType.label(
                                            FeatureRequestType.aplikasiBaru))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _type = v);
                                    _load();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Daftar Request (${_rows.length})',
                          icon: Icons.feedback_outlined,
                          child: _rows.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                      'Tidak ada request untuk filter ini'),
                                )
                              : Column(
                                  children: _rows
                                      .map((r) => Card(
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                            r.requestTitle,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ),
                                                      PopupMenuButton<String>(
                                                        initialValue:
                                                            r.requestStatus,
                                                        onSelected: (v) =>
                                                            _changeStatus(r, v),
                                                        itemBuilder: (context) =>
                                                            FeatureRequestStatus
                                                                .all
                                                                .map((s) =>
                                                                    PopupMenuItem(
                                                                      value: s,
                                                                      child: Text(
                                                                          FeatureRequestStatus.label(
                                                                              s)),
                                                                    ))
                                                                .toList(),
                                                        child: Chip(
                                                          label: Text(
                                                            FeatureRequestStatus
                                                                .label(r
                                                                    .requestStatus),
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 11),
                                                          ),
                                                          backgroundColor:
                                                              _statusColor(r
                                                                  .requestStatus),
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    [
                                                      FeatureRequestCategory
                                                          .label(r
                                                              .requestCategory),
                                                      FeatureRequestType.label(
                                                          r.requestType),
                                                      if (r.requestMenu
                                                          .isNotEmpty)
                                                        r.requestMenu,
                                                    ].join(' · '),
                                                    style: const TextStyle(
                                                        color: AppColors.muted,
                                                        fontSize: 12),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(r.requestDescription),
                                                  if (r.requestCreatedAt !=
                                                      null) ...[
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Gold ID ${r.requestGoldId} · ${r.requestCreatedAt}',
                                                      style: const TextStyle(
                                                          color: AppColors
                                                              .disabled,
                                                          fontSize: 11),
                                                    ),
                                                  ],
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
