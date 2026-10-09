import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/location_model.dart';
import '../services/location_api.dart';

/// 4 dropdown berjenjang (negara disembunyikan selama cuma Indonesia yang didukung -- lihat
/// rancangan deploy-notes/.../30-RANCANGAN-FITUR-LOKASI-OUTLET.md §6). Tiap dropdown anak
/// disabled+kosong sampai induknya dipilih. Level 3/4 otomatis tidak tampil kalau backend belum
/// punya data untuk level itu (mis. kecamatan/kelurahan belum di-seed) -- tidak di-hardcode "cuma
/// 2 level", murni mengikuti apa yang dikembalikan API.
///
/// Opsional: isi [initialSelection] (division_level4_id atau level terdalam yang tersedia) untuk
/// layar EDIT -- widget akan panggil breadcrumb sekali lalu isi semua dropdown sekaligus.
class LocationPicker extends StatefulWidget {
  final void Function(LocationSelection) onChanged;
  final int? initialDivisionId;

  const LocationPicker(
      {super.key, required this.onChanged, this.initialDivisionId});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _api = LocationApi();
  final _postalController = TextEditingController();

  // Indonesia hardcode sementara -- satu-satunya negara yang sudah di-seed (lihat migrasi
  // 20261003_location_hierarchy_seed_id.sql). Ganti ke dropdown negara begitu negara lain ditambah.
  static const int _indonesiaCountryId = 1;

  final List<List<LocationDivision>> _options = [[], [], [], []];
  final List<int?> _selected = [null, null, null, null];
  final List<bool> _loading = [false, false, false, false];
  bool _initLoading = true;

  @override
  void initState() {
    super.initState();
    _postalController.addListener(_emitChange);
    _bootstrap();
  }

  @override
  void dispose() {
    _postalController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.initialDivisionId != null) {
      await _loadFromBreadcrumb(widget.initialDivisionId!);
    } else {
      await _loadLevel(0, parentId: null);
    }
    if (mounted) setState(() => _initLoading = false);
  }

  Future<void> _loadFromBreadcrumb(int divisionId) async {
    try {
      final res = await _api.getBreadcrumb(divisionId);
      if (res.statusCode != 200) return;
      final chain = ((jsonDecode(res.body)['data'] ?? []) as List)
          .map((e) => LocationDivision.fromJson(e))
          .toList();
      // isi tiap level dari rantai (level 1-indexed di API, 0-indexed di _selected).
      for (final d in chain) {
        if (d.level >= 1 && d.level <= 4) _selected[d.level - 1] = d.divisionId;
      }
      // muat opsi tiap level supaya dropdown bisa menampilkan nama yang sudah terpilih.
      await _loadLevel(0, parentId: null, keepSelection: true);
      for (var i = 1; i < chain.length; i++) {
        await _loadLevel(i, parentId: _selected[i - 1], keepSelection: true);
      }
    } catch (_) {
      // gagal muat breadcrumb -- biarkan kosong, user bisa pilih manual dari awal.
    }
  }

  Future<void> _loadLevel(int levelIndex,
      {required int? parentId, bool keepSelection = false}) async {
    setState(() => _loading[levelIndex] = true);
    try {
      final res = await _api.getDivisions(
        countryId: _indonesiaCountryId,
        parentId: parentId,
        level: levelIndex + 1,
      );
      if (res.statusCode == 200) {
        final rows = ((jsonDecode(res.body)['data'] ?? []) as List)
            .map((e) => LocationDivision.fromJson(e))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (mounted) {
          setState(() {
            _options[levelIndex] = rows;
            if (!keepSelection) {
              for (var i = levelIndex; i < 4; i++) {
                if (i != levelIndex) _selected[i] = null;
              }
            }
          });
        }
      }
    } catch (_) {
      // gagal muat -- dropdown level ini tetap kosong, tidak memblokir sisa form.
    } finally {
      if (mounted) setState(() => _loading[levelIndex] = false);
    }
  }

  void _onSelect(int levelIndex, int? divisionId) {
    setState(() {
      _selected[levelIndex] = divisionId;
      for (var i = levelIndex + 1; i < 4; i++) {
        _selected[i] = null;
        _options[i] = [];
      }
    });
    _emitChange();
    if (divisionId != null && levelIndex < 3) {
      _loadLevel(levelIndex + 1, parentId: divisionId);
    }
  }

  void _emitChange() {
    final sel = LocationSelection(
      countryId: _selected[0] != null ? _indonesiaCountryId : null,
      level1Id: _selected[0],
      level2Id: _selected[1],
      level3Id: _selected[2],
      level4Id: _selected[3],
      postalCode: _postalController.text.trim().isEmpty
          ? null
          : _postalController.text.trim(),
    );
    widget.onChanged(sel);
  }

  static const _levelLabels = [
    'Provinsi',
    'Kabupaten/Kota',
    'Kecamatan',
    'Kelurahan/Desa'
  ];

  // Level 2 (index 1) dipisah jadi 2 dropdown terpisah -- Kabupaten & Kota -- bukan 1 daftar gabungan,
  // supaya user tidak perlu scroll campur aduk 514 nama. Nama di sumber data SELALU diawali kata
  // "Kabupaten" atau "Kota" (diverifikasi: 416 Kabupaten, 98 Kota, tidak ada pengecualian), jadi aman
  // dipisah murni dari prefix nama, bukan field terpisah di API.
  List<LocationDivision> get _kabupatenOptions =>
      _options[1].where((d) => d.name.startsWith('Kabupaten')).toList();
  List<LocationDivision> get _kotaOptions =>
      _options[1].where((d) => d.name.startsWith('Kota')).toList();

  Widget _buildDropdown({
    required String label,
    required List<LocationDivision> options,
    required int? value,
    required bool loading,
    required void Function(int?) onChanged,
    required Key key,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DropdownButtonFormField<int>(
        key: key,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.map_outlined),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : null,
        ),
        items: [
          for (final d in options)
            DropdownMenuItem(value: d.divisionId, child: Text(d.name)),
        ],
        onChanged: loading ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final selectedIsKabupaten =
        _kabupatenOptions.any((d) => d.divisionId == _selected[1]);
    final selectedIsKota =
        _kotaOptions.any((d) => d.divisionId == _selected[1]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var level = 0; level < 4; level++) ...[
          if (level == 0 || _selected[level - 1] != null) ...[
            if (level == 1) ...[
              if (_kabupatenOptions.isNotEmpty || _loading[1])
                _buildDropdown(
                  // KOREKSI 2026-10-09: key HARUS ikut nilai yang ditampilkan widget ini sendiri
                  // (bukan cuma induknya) -- DropdownButtonFormField.initialValue TIDAK reaktif
                  // (dibaca cuma sekali saat widget dibuat), jadi tanpa ini, berpindah Kabupaten<->Kota
                  // (yang berbagi slot _selected[1] yang sama) tidak memicu Flutter membuat ulang
                  // widget & tampilan desync/tampak "terhapus" dari yang sebenarnya tersimpan.
                  key: ValueKey(
                      'loc-kabupaten-${_selected[0]}-${selectedIsKabupaten ? _selected[1] : null}'),
                  label: 'Kabupaten',
                  options: _kabupatenOptions,
                  value: selectedIsKabupaten ? _selected[1] : null,
                  loading: _loading[1],
                  onChanged: (v) => _onSelect(1, v),
                ),
              if (_kotaOptions.isNotEmpty || _loading[1])
                _buildDropdown(
                  key: ValueKey(
                      'loc-kota-${_selected[0]}-${selectedIsKota ? _selected[1] : null}'),
                  label: 'Kota',
                  options: _kotaOptions,
                  value: selectedIsKota ? _selected[1] : null,
                  loading: _loading[1],
                  onChanged: (v) => _onSelect(1, v),
                ),
            ] else if (_options[level].isNotEmpty || _loading[level]) ...[
              _buildDropdown(
                key: ValueKey(
                    'loc-level-$level-${_selected[level - 1].toString()}-${_selected[level]}'),
                label: _levelLabels[level],
                options: _options[level],
                value: _selected[level],
                loading: _loading[level],
                onChanged: (v) => _onSelect(level, v),
              ),
            ],
          ],
        ],
        if (_selected[0] != null) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _postalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kode Pos (opsional)',
              prefixIcon: Icon(Icons.local_post_office_outlined),
            ),
          ),
        ],
      ],
    );
  }
}
