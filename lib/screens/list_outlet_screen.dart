import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/outlet_api.dart';
import '../models/outlet_model.dart';
import '../models/outlet_tax_model.dart';
import '../utils/roles.dart';
import '../utils/toast.dart';
import '../widgets/auth_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/search_field.dart';
import '../widgets/tour_target.dart';
import '../utils/tour_demo.dart';

class ListOutletScreen extends StatefulWidget {
  const ListOutletScreen({super.key});

  @override
  State<ListOutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<ListOutletScreen> {
  // STAFF: daftar outlet baca-saja (backend menolak ubah/hapus).
  bool _isStaff = false;
  final outletsApi = OutletsApi();
  final _outletAddressController = TextEditingController();
  final _outletSearchListController = TextEditingController();

  final ValueNotifier<String> statusEditNotifier = ValueNotifier("ACTIVE");

  bool _isLoading = true;
  int lengths = 5;
  int pages = 1;
  Timer? _searchDebounce;

  ValueNotifier<OutletPagination?> outletsPaginationNotifier =
      ValueNotifier(null);
  ValueNotifier<int> editingIndexNotifier = ValueNotifier(-1);

  @override
  void initState() {
    super.initState();
    isStaffRole().then((v) {
      if (mounted && v) setState(() => _isStaff = true);
    });

    loadItemsOnStart();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _outletAddressController.dispose();
    _outletSearchListController.dispose();
    statusEditNotifier.dispose();
    outletsPaginationNotifier.dispose();
    editingIndexNotifier.dispose();
    super.dispose();
  }

  Future<void> loadItemsOnStart() async {
    if (outletsPaginationNotifier.value == null ||
        outletsPaginationNotifier.value!.data.isEmpty) {
      await getAllOutlet("", 1, 5);
    }
  }

  Future<void> getAllOutlet(String name, int page, int length) async {
    setState(() => _isLoading = true);
    try {
      final response = await outletsApi.getAllOutlet(name, "", page, length);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        pages = page;
        lengths = length;

        outletsPaginationNotifier.value = OutletPagination.fromJson(data);
      } else {
        Toast.error(context, 'Gagal memuat daftar outlet');
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memuat daftar outlet');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      getAllOutlet(value, 1, lengths);
    });
  }

  Future<void> updateOutletRow(OutletResponse item) async {
    final body = {
      "data": {
        "outlet_code": item.outlet_code,
        "outlet_address": _outletAddressController.text.isEmpty
            ? ""
            : _outletAddressController.text,
        "outlet_status": statusEditNotifier.value,
      }
    };

    try {
      final response = await outletsApi.updateOutlets(body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Outlet berhasil diperbarui');
      } else {
        Toast.error(context, 'Gagal memperbarui outlet');
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memperbarui outlet');
    }
  }

  void _startEdit(int index, OutletResponse item) {
    editingIndexNotifier.value = index;
    _outletAddressController.text = item.outlet_address;
    statusEditNotifier.value =
        item.outlet_status.isEmpty ? "ACTIVE" : item.outlet_status;
  }

  Future<void> _saveEdit(OutletResponse item) async {
    await updateOutletRow(item);
    editingIndexNotifier.value = -1;
    await getAllOutlet(_outletSearchListController.text, pages, lengths);
    _outletAddressController.clear();
  }

  void _cancelEdit() {
    editingIndexNotifier.value = -1;
    _outletAddressController.clear();
  }

  Future<void> _confirmDeleteOutlet(OutletResponse item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Outlet'),
        content: Text('Yakin ingin menghapus outlet "${item.outlet_name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await outletsApi.deleteOutlet(item.outlet_code);
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Outlet berhasil dihapus');
        await getAllOutlet(_outletSearchListController.text, pages, lengths);
      } else {
        String message = "Gagal menghapus outlet";
        try {
          final body = jsonDecode(response.body);
          if (body['error'] != null) message = body['error'];
        } catch (_) {}
        Toast.error(context, message);
      }
    } catch (e) {
      if (!mounted) return;
      Toast.error(context, 'Error menghapus outlet');
    }
  }

  /// Pengaturan pajak outlet (2026-11-17, T4 tahap 1): hanya pemilik; server menolak peran lain.
  Future<void> _openTaxDialog(OutletResponse item) async {
    TaxSettings cur = TaxSettings.off;
    try {
      final resp = await outletsApi.getTax(item.outlet_code);
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body)['data'];
        if (d is Map) cur = TaxSettings.fromJson(Map<String, dynamic>.from(d));
      }
    } catch (_) {}
    if (!mounted) return;

    var form = cur;
    final nameCtl = TextEditingController(text: cur.name);
    final pctCtl = TextEditingController(
        text: cur.percent > 0
            ? (cur.percent.truncateToDouble() == cur.percent
                ? cur.percent.toStringAsFixed(0)
                : '${cur.percent}')
            : '11');
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setD) => AlertDialog(
          title: Text('Pengaturan pajak · ${item.outlet_name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(form.enabled ? 'Pajak AKTIF' : 'Pajak MATI (bawaan)'),
                  value: form.enabled,
                  onChanged: (v) => setD(() => form = form.copyWith(enabled: v)),
                ),
                if (form.enabled) ...[
                  TextField(
                    controller: nameCtl,
                    maxLength: 20,
                    decoration: const InputDecoration(
                        labelText: 'Nama pajak (mis. PPN, PB1)'),
                  ),
                  TextField(
                    controller: pctCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Persen (%)'),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: true,
                          label: Text('Sudah termasuk', maxLines: 2)),
                      ButtonSegment(
                          value: false,
                          label: Text('Belum termasuk', maxLines: 2)),
                    ],
                    selected: {form.inclusive},
                    onSelectionChanged: (v) =>
                        setD(() => form = form.copyWith(inclusive: v.first)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    form.inclusive
                        ? 'Harga sudah termasuk pajak. Total tidak berubah; bagian pajak ditampilkan di struk.'
                        : 'Harga belum termasuk pajak. Pajak ditambahkan di atas total setelah diskon dan voucher. Wajib memakai aplikasi versi terbaru di semua perangkat kasir.',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final percent =
                          double.tryParse(pctCtl.text.trim().replaceAll(',', '.')) ??
                              double.nan;
                      if (form.enabled &&
                          (percent.isNaN || percent <= 0 || percent > 100)) {
                        Toast.error(
                            context, 'Persen pajak harus antara 0 dan 100');
                        return;
                      }
                      setD(() => saving = true);
                      try {
                        // percent dikirim sebagai ANGKA (server menolak string).
                        final res = await outletsApi.setTax(item.outlet_code, {
                          'enabled': form.enabled,
                          'name': nameCtl.text.trim().isEmpty
                              ? 'PPN'
                              : nameCtl.text.trim(),
                          'percent': form.enabled ? percent : 0,
                          'inclusive': form.inclusive,
                        });
                        if (!mounted) return;
                        if (res.statusCode == 200) {
                          Toast.success(context, 'Pengaturan pajak disimpan');
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        } else {
                          String msg = 'Gagal menyimpan pengaturan pajak';
                          try {
                            msg = jsonDecode(res.body)['error'] ?? msg;
                          } catch (_) {}
                          Toast.error(context, msg);
                          setD(() => saving = false);
                        }
                      } catch (_) {
                        if (mounted) {
                          Toast.error(
                              context, 'Gagal menyimpan pengaturan pajak');
                          setD(() => saving = false);
                        }
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleQueue(OutletResponse item) async {
    try {
      final response =
          await outletsApi.setQueueEnabled(item.outlet_code, !item.queueEnabled);
      if (!mounted) return;
      if (response.statusCode == 200) {
        await getAllOutlet(_outletSearchListController.text, pages, lengths);
      } else {
        String message = "Gagal mengubah status antrian";
        try {
          final body = jsonDecode(response.body);
          if (body['error'] != null) message = body['error'];
        } catch (_) {}
        Toast.error(context, message);
      }
    } catch (e) {
      if (!mounted) return;
      Toast.error(context, 'Gagal mengubah status antrian');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Daftar Outlet',
      subtitle: 'Ubah alamat/status, atau hapus outlet yang tidak dipakai',
      maxWidth: 720,
      showLogo: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SearchField(
            controller: _outletSearchListController,
            hintText: 'Cari nama outlet...',
            onChanged: _onSearchChanged,
            onSubmitted: (v) => getAllOutlet(v, 1, lengths),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<OutletPagination?>(
            valueListenable: outletsPaginationNotifier,
            builder: (context, pagination, child) {
              if (_isLoading && pagination == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (pagination == null || pagination.data.isEmpty) {
                return TourDemo.when(
                  demo: () => TourDemoBlock(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.storefront_outlined),
                        title: const Text('Outlet Contoh',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Jl. Contoh No. 1 - ACTIVE'),
                        trailing: TourTarget(
                          id: 'outlet-queue-toggle',
                          child: ElevatedButton(
                              onPressed: null, child: const Text('AKTIF')),
                        ),
                      ),
                    ),
                  ),
                  normal: () => const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Belum ada outlet',
                    description:
                        'Outlet yang Anda buat akan tampil di sini. Buat lewat '
                        'tombol NEW OUTLET di halaman Pilih Outlet.',
                    compact: true,
                  ),
                );
              }

              final items = pagination.data;

              // listen editing index tanpa refresh seluruh halaman
              return ValueListenableBuilder<int>(
                valueListenable: editingIndexNotifier,
                builder: (context, editingIndex, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OutletTile(
                            number: ((pagination.page - 1) * pagination.limit) +
                                i +
                                1,
                            item: items[i],
                            isEditing: editingIndex == i,
                            readOnly: _isStaff,
                            addressController: _outletAddressController,
                            statusNotifier: statusEditNotifier,
                            onEdit: () => _startEdit(i, items[i]),
                            onSave: () => _saveEdit(items[i]),
                            onCancel: _cancelEdit,
                            onDelete: () => _confirmDeleteOutlet(items[i]),
                            onToggleQueue: () => _toggleQueue(items[i]),
                            onTax: () => _openTaxDialog(items[i]),
                            tourFirst: i == 0,
                          ),
                        ),
                      const SizedBox(height: 4),
                      PaginationBar(
                        page: pagination.page,
                        totalPage: pagination.totalPage,
                        limit: pagination.limit,
                        totalData: pagination.totalData,
                        shownCount: pagination.data.length,
                        onPageChanged: (p) => getAllOutlet(
                            _outletSearchListController.text,
                            p,
                            pagination.limit),
                        onLimitChanged: (l) => getAllOutlet(
                            _outletSearchListController.text, 1, l),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/outlet');
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: const Text('KEMBALI'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutletTile extends StatelessWidget {
  final int number;
  final OutletResponse item;
  final bool isEditing;
  final TextEditingController addressController;
  final ValueNotifier<String> statusNotifier;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onToggleQueue;
  final VoidCallback onTax;
  final bool readOnly;
  // baris pertama = target Panduan Penggunaan (tombol antrian)
  final bool tourFirst;

  const _OutletTile({
    required this.number,
    required this.item,
    required this.isEditing,
    required this.addressController,
    required this.statusNotifier,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    required this.onDelete,
    required this.onToggleQueue,
    required this.onTax,
    this.readOnly = false,
    this.tourFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = item.deleted
        ? 'DIHAPUS'
        : item.outlet_status.isEmpty
            ? '-'
            : (item.outlet_status == 'INACTIVE'
                ? 'NONACTIVE'
                : item.outlet_status);
    final active = item.outlet_status == 'ACTIVE';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: isEditing ? AppColors.blue : AppColors.border,
            width: isEditing ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.blueLight,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.outlet_name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      item.locked
                          ? '${item.outlet_code} · 🔒 Terkunci: melebihi batas paket'
                          : item.outlet_code,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isEditing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: active ? AppColors.successLight : AppColors.chipBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.successDark : AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEditing) ...[
            TextField(
              controller: addressController,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alamat',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, value, _) {
                final current =
                    value == 'ACTIVE' || value == 'INACTIVE' ? value : 'ACTIVE';
                return DropdownButtonFormField<String>(
                  key: ValueKey(current),
                  initialValue: current,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: "ACTIVE", child: Text("ACTIVE")),
                    DropdownMenuItem(
                        value: "INACTIVE", child: Text("NONACTIVE")),
                  ],
                  onChanged: (val) {
                    if (val != null) statusNotifier.value = val;
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successDark),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.outlet_address.isEmpty ? '-' : item.outlet_address,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style:
                        textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
            // Lokasi (2026-10-03, opsional): bedakan outlet bernama sama di kota berbeda.
            if (item.locationLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.map_outlined, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
            if (!item.deleted && !item.locked) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.format_list_numbered_rounded,
                      size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  const Text('Antrian POS', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  TourTarget(
                    id: 'outlet-queue-toggle',
                    enabled: tourFirst,
                    child: OutlinedButton(
                    onPressed: readOnly ? null : onToggleQueue,
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          item.queueEnabled ? AppColors.successLight : null,
                      foregroundColor:
                          item.queueEnabled ? AppColors.successDark : null,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(item.queueEnabled ? 'AKTIF' : 'NONAKTIF'),
                  )),
                ],
              ),
            ],
            if (!readOnly && !item.deleted) ...[
              const SizedBox(height: 10),
              // Pajak di baris sendiri: tiga tombol sejajar terlalu sempit di HP (teks terpotong "Paja/k").
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: item.locked ? null : onTax,
                  icon: const Icon(Icons.percent_rounded, size: 18),
                  label: const Text('Pajak'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      // outlet terkunci tidak bisa diubah; hapus tetap boleh untuk mengosongkan slot
                      onPressed: item.locked ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
