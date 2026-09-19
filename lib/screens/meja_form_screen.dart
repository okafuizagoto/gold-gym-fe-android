import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/area_model.dart';
import '../services/area_api.dart';
import '../services/meja_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Form "Tambah Meja" -- satu meja atau bulk (pola nama berurutan, mis.
/// A1 -> A1,A2,A3), dengan kapasitas (jumlah pelanggan) sama semua atau
/// per-meja, dan pilih area.
class MejaFormScreen extends StatefulWidget {
  const MejaFormScreen({super.key});

  @override
  State<MejaFormScreen> createState() => _MejaFormScreenState();
}

class _MejaFormScreenState extends State<MejaFormScreen> {
  final _areaApi = AreaApi();
  final _mejaApi = MejaApi();

  final _startNameController = TextEditingController();
  final _countController = TextEditingController(text: '2');
  final _sameCapacityController = TextEditingController(text: '4');

  bool _isBulk = false;
  bool _sameCapacityForAll = true;
  bool _saving = false;
  bool _loadingAreas = true;

  List<Area> _areas = [];
  int? _selectedAreaId;

  List<String> _previewNames = [];
  String? _nameError;
  final Map<String, TextEditingController> _perNameCapacity = {};

  static final RegExp _trailingDigit = RegExp(r'^(.*?)(\d+)$');

  @override
  void initState() {
    super.initState();
    _loadAreas();
    _startNameController.addListener(_regeneratePreview);
    _countController.addListener(_regeneratePreview);
  }

  @override
  void dispose() {
    _startNameController.dispose();
    _countController.dispose();
    _sameCapacityController.dispose();
    for (final c in _perNameCapacity.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAreas() async {
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    try {
      final response = await _areaApi.getAreas(outcode);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list =
            (body['data'] as List? ?? []).map((e) => Area.fromJson(e)).toList();
        setState(() {
          _areas = list;
          _selectedAreaId = list.isNotEmpty ? list.first.areaId : null;
          _loadingAreas = false;
        });
      } else {
        setState(() => _loadingAreas = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAreas = false);
    }
  }

  /// Port dari algoritma GenerateSequentialNames (Go, internal/service/meja) --
  /// harus tetap identik supaya preview di sini konsisten dengan yang
  /// tervalidasi di backend.
  List<String>? _generateNames(String start, int count) {
    final trimmed = start.trim();
    if (trimmed.isEmpty) {
      setState(() => _nameError = 'Nama awal wajib diisi');
      return null;
    }
    if (count < 1) {
      setState(() => _nameError = 'Jumlah meja minimal 1');
      return null;
    }

    final match = _trailingDigit.firstMatch(trimmed);
    if (match == null) {
      setState(() => _nameError =
          'Nama awal untuk mode banyak meja harus diakhiri angka, contoh: A1, MEJA01');
      return null;
    }

    final prefix = match.group(1)!;
    final digits = match.group(2)!;
    final width = digits.length;
    final startNum = int.parse(digits);

    setState(() => _nameError = null);
    return List.generate(count, (i) {
      final num = startNum + i;
      return '$prefix${num.toString().padLeft(width, '0')}';
    });
  }

  void _regeneratePreview() {
    if (!_isBulk) return;
    final count = int.tryParse(_countController.text.trim()) ?? 0;
    final names = _generateNames(_startNameController.text, count) ?? [];

    // Sinkronkan controller kapasitas per-nama: pertahankan nilai yang
    // sudah diisi user untuk nama yang masih ada, buang yang sudah tidak
    // relevan, tambah default untuk nama baru.
    final newControllers = <String, TextEditingController>{};
    for (final n in names) {
      newControllers[n] = _perNameCapacity[n] ??
          TextEditingController(text: _sameCapacityController.text);
    }
    for (final entry in _perNameCapacity.entries) {
      if (!newControllers.containsKey(entry.key)) entry.value.dispose();
    }

    setState(() {
      _previewNames = names;
      _perNameCapacity
        ..clear()
        ..addAll(newControllers);
    });
  }

  Future<void> _save() async {
    if (_selectedAreaId == null) {
      Toast.error(context, 'Area wajib dipilih');
      return;
    }

    final rows = <Map<String, dynamic>>[];

    if (!_isBulk) {
      final name = _startNameController.text.trim();
      if (name.isEmpty) {
        Toast.error(context, 'Nama/nomor meja wajib diisi');
        return;
      }
      final capacity = int.tryParse(_sameCapacityController.text.trim()) ?? 0;
      if (capacity < 1) {
        Toast.error(context, 'Jumlah pelanggan (kapasitas) minimal 1');
        return;
      }
      rows.add({
        'meja_name': name,
        'meja_capacity': capacity,
        'meja_area_id': _selectedAreaId,
      });
    } else {
      if (_nameError != null) {
        Toast.error(context, _nameError!);
        return;
      }
      if (_previewNames.isEmpty) {
        Toast.error(context, 'Belum ada preview nama meja');
        return;
      }
      final sameCapacity =
          int.tryParse(_sameCapacityController.text.trim()) ?? 0;
      for (final name in _previewNames) {
        final capacity = _sameCapacityForAll
            ? sameCapacity
            : int.tryParse(_perNameCapacity[name]?.text.trim() ?? '') ?? 0;
        if (capacity < 1) {
          Toast.error(context, 'Kapasitas meja "$name" minimal 1');
          return;
        }
        rows.add({
          'meja_name': name,
          'meja_capacity': capacity,
          'meja_area_id': _selectedAreaId,
        });
      }
    }

    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (outcode.isEmpty) {
      if (mounted) Toast.error(context, 'Outlet belum dipilih');
      return;
    }

    setState(() => _saving = true);
    try {
      final response = await _mejaApi.insertMeja({
        'outcode': outcode,
        'data': rows,
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Meja berhasil ditambahkan');
        Navigator.pop(context, true);
      } else {
        final body = jsonDecode(response.body);
        Toast.error(
            context, body['error']?.toString() ?? 'Gagal menambah meja');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menambah meja');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Tambah Meja'),
        body: _loadingAreas
            ? const Center(child: CircularProgressIndicator())
            : _areas.isEmpty
                ? PageBody(
                    maxWidth: 560,
                    child: EmptyState(
                      icon: Icons.map_outlined,
                      title: 'Belum ada area',
                      description:
                          'Buat area terlebih dahulu di tab Area sebelum menambah meja.',
                      action: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        label: const Text('Kembali'),
                      ),
                    ),
                  )
                : _buildForm(),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }

  Widget _buildForm() {
    final textTheme = Theme.of(context).textTheme;
    return PageBody(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Tambah Meja',
            subtitle:
                'Satu meja, atau banyak sekaligus dengan pola nama berurutan (A1, A2, ...).',
            icon: Icons.table_bar_rounded,
          ),
          SectionCard(
            title: 'Nama & Jumlah',
            icon: Icons.tag_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _startNameController,
                  decoration: InputDecoration(
                    labelText:
                        _isBulk ? 'Nama/Nomor Meja Awal' : 'Nama/Nomor Meja',
                    hintText: 'mis. A1',
                    errorText: _isBulk ? _nameError : null,
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                _switchTile(
                  title: 'Tambah banyak meja sekaligus',
                  value: _isBulk,
                  onChanged: (v) {
                    setState(() => _isBulk = v);
                    _regeneratePreview();
                  },
                ),
                if (_isBulk) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Meja',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Kapasitas',
            description: 'Jumlah pelanggan yang muat di satu meja',
            icon: Icons.groups_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isBulk) ...[
                  _switchTile(
                    title: 'Samakan jumlah pelanggan untuk semua meja',
                    value: _sameCapacityForAll,
                    onChanged: (v) => setState(() => _sameCapacityForAll = v),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_isBulk || _sameCapacityForAll)
                  TextFormField(
                    controller: _sameCapacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Pelanggan (Kapasitas)',
                    ),
                  )
                else
                  Text(
                    'Isi kapasitas tiap meja di bagian Pratinjau di bawah.',
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Area',
            icon: Icons.map_outlined,
            child: DropdownButtonFormField<int>(
              initialValue: _selectedAreaId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Area',
              ),
              items: _areas
                  .map((a) => DropdownMenuItem(
                        value: a.areaId,
                        child: Text(
                          '${a.areaName} (${a.areaType})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedAreaId = v),
            ),
          ),
          if (_isBulk && _previewNames.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Pratinjau Meja',
              description: '${_previewNames.length} meja akan dibuat',
              icon: Icons.preview_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final name in _previewNames)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.blueLight,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.blueDark,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!_sameCapacityForAll)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: 130, minWidth: 90),
                              child: TextFormField(
                                controller: _perNameCapacity[name],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Kapasitas',
                                  isDense: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 20),
              label: const Text('SIMPAN'),
            ),
          ),
        ],
      ),
    );
  }
}
