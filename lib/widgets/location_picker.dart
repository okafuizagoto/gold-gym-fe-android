import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/location_model.dart';
import '../providers/language_provider.dart';
import '../services/location_api.dart';

/// Dropdown berjenjang lokasi (negara disembunyikan selama cuma Indonesia yang didukung -- lihat
/// rancangan deploy-notes/.../30-RANCANGAN-FITUR-LOKASI-OUTLET.md §6).
///
/// Kabupaten & Kota adalah field independen (state terpisah, tidak berbagi 1 slot) -- memilih
/// salah satu TIDAK menghapus tampilan yang lain. Kecamatan mengikuti SIAPAPUN (Kabupaten atau
/// Kota) yang terakhir dipilih sebagai induknya. Saat dikirim ke backend, division_level2_id =
/// kabupaten ?? kota (satu kolom yang sama).
///
/// Urutan tampilan: Provinsi, Kabupaten, Kota, Kecamatan, Kelurahan/Desa, Kode Pos.
///
/// 2026-10-09 (gating bertahap): SEMUA field SELALU tampil sejak awal -- tapi DISABLED sampai
/// field sebelum yang mewajibkannya terisi. Hanya Provinsi yang aktif di awal. Field BARU
/// disembunyikan sepenuhnya kalau query-nya SUDAH SELESAI (sukses) dan hasilnya terbukti kosong
/// (bukan karena belum dicek) -- itulah tanda "memang tidak ada data seed-nya".
class _FieldState {
  final bool visible;
  final bool enabled;
  final bool loading;
  const _FieldState(
      {required this.visible, required this.enabled, required this.loading});

  factory _FieldState.compute(
      bool precondition, bool loaded, bool loading, int optionsLen) {
    if (!precondition) {
      return const _FieldState(visible: true, enabled: false, loading: false);
    }
    if (loading) {
      return const _FieldState(visible: true, enabled: false, loading: true);
    }
    if (loaded && optionsLen == 0) {
      return const _FieldState(visible: false, enabled: false, loading: false);
    }
    if (loaded && optionsLen > 0) {
      return const _FieldState(visible: true, enabled: true, loading: false);
    }
    return const _FieldState(visible: true, enabled: false, loading: false);
  }
}

class LocationPicker extends StatefulWidget {
  final void Function(LocationSelection) onChanged;
  final void Function(bool complete)? onValidityChange;
  final int? initialDivisionId;

  const LocationPicker({
    super.key,
    required this.onChanged,
    this.onValidityChange,
    this.initialDivisionId,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _api = LocationApi();
  final _postalController = TextEditingController();

  static const int _indonesiaCountryId = 1;

  List<LocationDivision> _provinsiOptions = [];
  List<LocationDivision> _level2Options =
      []; // kabupaten+kota mentah, difilter di bawah
  List<LocationDivision> _kecamatanOptions = [];
  List<LocationDivision> _kelurahanOptions = [];

  int? _provinsi;
  int? _kabupaten;
  int? _kota;
  int? _kecamatan;
  int? _kelurahan;

  // Induk Kecamatan: siapapun (Kabupaten/Kota) yang terakhir dipilih.
  int? _level2ActiveParent;

  bool _loadingLevel2 = false;
  bool _loadingKecamatan = false;
  bool _loadingKelurahan = false;
  bool _initLoading = true;

  // "Loaded": true setelah query level itu SELESAI (sukses), terlepas hasilnya kosong atau tidak.
  bool _level2Loaded = false;
  bool _kecamatanLoaded = false;
  bool _kelurahanLoaded = false;

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
    await _loadProvinsi();
    if (widget.initialDivisionId != null) {
      await _loadFromBreadcrumb(widget.initialDivisionId!);
    }
    if (mounted) setState(() => _initLoading = false);
    _emitValidity();
  }

  Future<void> _loadProvinsi() async {
    try {
      final res = await _api.getDivisions(
          countryId: _indonesiaCountryId, parentId: null, level: 1);
      if (res.statusCode == 200) {
        final rows = ((jsonDecode(res.body)['data'] ?? []) as List)
            .map((e) => LocationDivision.fromJson(e))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (mounted) setState(() => _provinsiOptions = rows);
      }
    } catch (_) {
      // gagal muat -- dropdown tetap kosong, tidak memblokir sisa form.
    }
  }

  Future<void> _loadLevel2(int parentId) async {
    if (mounted) setState(() => _loadingLevel2 = true);
    try {
      final res = await _api.getDivisions(
          countryId: _indonesiaCountryId, parentId: parentId, level: 2);
      if (res.statusCode == 200) {
        final rows = ((jsonDecode(res.body)['data'] ?? []) as List)
            .map((e) => LocationDivision.fromJson(e))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (mounted) {
          setState(() {
            _level2Options = rows;
            _level2Loaded = true;
          });
        }
      }
    } catch (_) {
      // gagal muat -- jangan tandai loaded.
    } finally {
      if (mounted) setState(() => _loadingLevel2 = false);
      _emitValidity();
    }
  }

  Future<void> _loadKecamatan(int parentId) async {
    if (mounted) setState(() => _loadingKecamatan = true);
    try {
      final res = await _api.getDivisions(
          countryId: _indonesiaCountryId, parentId: parentId, level: 3);
      if (res.statusCode == 200) {
        final rows = ((jsonDecode(res.body)['data'] ?? []) as List)
            .map((e) => LocationDivision.fromJson(e))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (mounted) {
          setState(() {
            _kecamatanOptions = rows;
            _kecamatanLoaded = true;
          });
        }
      }
    } catch (_) {
      // gagal muat -- jangan tandai loaded.
    } finally {
      if (mounted) setState(() => _loadingKecamatan = false);
      _emitValidity();
    }
  }

  Future<void> _loadKelurahan(int parentId) async {
    if (mounted) setState(() => _loadingKelurahan = true);
    try {
      final res = await _api.getDivisions(
          countryId: _indonesiaCountryId, parentId: parentId, level: 4);
      if (res.statusCode == 200) {
        final rows = ((jsonDecode(res.body)['data'] ?? []) as List)
            .map((e) => LocationDivision.fromJson(e))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (mounted) {
          setState(() {
            _kelurahanOptions = rows;
            _kelurahanLoaded = true;
          });
        }
      }
    } catch (_) {
      // gagal muat -- jangan tandai loaded (otomatis tidak tampil kalau memang tidak ada data).
    } finally {
      if (mounted) setState(() => _loadingKelurahan = false);
      _emitValidity();
    }
  }

  Future<void> _loadFromBreadcrumb(int divisionId) async {
    try {
      final res = await _api.getBreadcrumb(divisionId);
      if (res.statusCode != 200) return;
      final chain = ((jsonDecode(res.body)['data'] ?? []) as List)
          .map((e) => LocationDivision.fromJson(e))
          .toList();
      final byLevel = <int, LocationDivision>{
        for (final d in chain) d.level: d,
      };
      if (byLevel[1] != null) _provinsi = byLevel[1]!.divisionId;
      if (byLevel[2] != null) {
        final d2 = byLevel[2]!;
        if (d2.name.startsWith('Kota')) {
          _kota = d2.divisionId;
        } else {
          _kabupaten = d2.divisionId;
        }
        _level2ActiveParent = d2.divisionId;
        await _loadLevel2(byLevel[1]?.divisionId ?? 0);
        await _loadKecamatan(d2.divisionId);
      }
      if (byLevel[3] != null) {
        _kecamatan = byLevel[3]!.divisionId;
        await _loadKelurahan(byLevel[3]!.divisionId);
      }
      if (byLevel[4] != null) _kelurahan = byLevel[4]!.divisionId;
      if (mounted) setState(() {});
    } catch (_) {
      // gagal muat breadcrumb -- biarkan kosong, user bisa pilih manual dari awal.
    }
  }

  void _emitChange() {
    final sel = LocationSelection(
      countryId: _provinsi != null ? _indonesiaCountryId : null,
      level1Id: _provinsi,
      // _level2ActiveParent (BUKAN _kabupaten ?? _kota) -- ketemu nyata 2026-10-09: kalau user
      // mengisi Kabupaten DULU lalu Kota (field independen, tidak saling menghapus), "kabupaten ??
      // kota" selalu memprioritaskan Kabupaten meski Kecamatan/Kelurahan yang sebenarnya dipilih
      // adalah anak dari Kota -- payload jadi rantai lokasi TIDAK KONSISTEN (level2 dari Kabupaten,
      // level3/4 dari Kota) dan backend menolaknya (500, sekarang diperbaiki jadi 400 juga).
      // _level2ActiveParent SELALU menunjuk induk yang benar-benar dipakai memuat Kecamatan.
      level2Id: _level2ActiveParent,
      level3Id: _kecamatan,
      level4Id: _kelurahan,
      postalCode: _postalController.text.trim().isEmpty
          ? null
          : _postalController.text.trim(),
    );
    widget.onChanged(sel);
    _emitValidity();
  }

  // Lengkap = semua level yang TERBUKTI punya data (query sukses & hasilnya tidak kosong) sudah
  // terisi. Level tanpa data (belum di-seed) tidak ikut dihitung sama sekali -- otomatis opsional.
  void _emitValidity() {
    if (widget.onValidityChange == null) return;
    bool complete = _provinsi != null;
    if (complete && _level2Loaded) {
      final needKabupaten = _kabupatenOptions.isNotEmpty;
      final needKota = _kotaOptions.isNotEmpty;
      if (needKabupaten && needKota) {
        complete = _kabupaten != null || _kota != null;
      } else if (needKabupaten) {
        complete = _kabupaten != null;
      } else if (needKota) {
        complete = _kota != null;
      }
    } else if (complete) {
      complete = false;
    }
    final level2Picked = _kabupaten != null || _kota != null;
    if (complete && level2Picked) {
      if (!_kecamatanLoaded) {
        complete = false;
      } else if (_kecamatanOptions.isNotEmpty) {
        complete = _kecamatan != null;
      }
    }
    if (complete && _kecamatan != null) {
      if (!_kelurahanLoaded) {
        complete = false;
      } else if (_kelurahanOptions.isNotEmpty) {
        complete = _kelurahan != null;
      }
    }
    widget.onValidityChange!(complete);
  }

  void _onSelectProvinsi(int? id) {
    setState(() {
      _provinsi = id;
      _kabupaten = null;
      _kota = null;
      _kecamatan = null;
      _kelurahan = null;
      _level2ActiveParent = null;
      _level2Options = [];
      _kecamatanOptions = [];
      _kelurahanOptions = [];
      _level2Loaded = false;
      _kecamatanLoaded = false;
      _kelurahanLoaded = false;
    });
    _emitChange();
    if (id != null) _loadLevel2(id);
  }

  void _onSelectKabupaten(int? id) {
    setState(() {
      _kabupaten = id;
      if (id != null) {
        _level2ActiveParent = id;
        _kecamatan = null;
        _kelurahan = null;
        _kelurahanOptions = [];
        _kecamatanLoaded = false;
        _kelurahanLoaded = false;
      }
    });
    _emitChange();
    if (id != null) _loadKecamatan(id);
  }

  void _onSelectKota(int? id) {
    setState(() {
      _kota = id;
      if (id != null) {
        _level2ActiveParent = id;
        _kecamatan = null;
        _kelurahan = null;
        _kelurahanOptions = [];
        _kecamatanLoaded = false;
        _kelurahanLoaded = false;
      }
    });
    _emitChange();
    if (id != null) _loadKecamatan(id);
  }

  void _onSelectKecamatan(int? id) {
    setState(() {
      _kecamatan = id;
      _kelurahan = null;
      _kelurahanOptions = [];
      _kelurahanLoaded = false;
    });
    _emitChange();
    if (id != null) _loadKelurahan(id);
  }

  void _onSelectKelurahan(int? id) {
    setState(() => _kelurahan = id);
    _emitChange();
  }

  Widget _buildDropdown({
    required String label,
    required List<LocationDivision> options,
    required int? value,
    required _FieldState state,
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
          suffixIcon: state.loading
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
        onChanged: state.enabled ? onChanged : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
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
    final requiredSuffix = ' (${lang.get('required', 'wajib')})';

    final kabupatenState = _FieldState.compute(_provinsi != null, _level2Loaded,
        _loadingLevel2, _kabupatenOptions.length);
    final kotaState = _FieldState.compute(
        _provinsi != null, _level2Loaded, _loadingLevel2, _kotaOptions.length);
    final level2Picked = _kabupaten != null || _kota != null;
    final kecamatanState = _FieldState.compute(level2Picked, _kecamatanLoaded,
        _loadingKecamatan, _kecamatanOptions.length);
    final kelurahanState = _FieldState.compute(_kecamatan != null,
        _kelurahanLoaded, _loadingKelurahan, _kelurahanOptions.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDropdown(
          key: const ValueKey('loc-provinsi'),
          label: lang.get('Province', 'Provinsi'),
          options: _provinsiOptions,
          value: _provinsi,
          state:
              const _FieldState(visible: true, enabled: true, loading: false),
          onChanged: _onSelectProvinsi,
        ),
        if (kabupatenState.visible)
          _buildDropdown(
            key: ValueKey('loc-kabupaten-$_provinsi-$_kabupaten'),
            label: lang.get('Regency', 'Kabupaten') + requiredSuffix,
            options: _kabupatenOptions,
            value: _kabupaten,
            state: kabupatenState,
            onChanged: _onSelectKabupaten,
          ),
        if (kotaState.visible)
          _buildDropdown(
            key: ValueKey('loc-kota-$_provinsi-$_kota'),
            label: lang.get('City', 'Kota') + requiredSuffix,
            options: _kotaOptions,
            value: _kota,
            state: kotaState,
            onChanged: _onSelectKota,
          ),
        if (kecamatanState.visible)
          _buildDropdown(
            key: ValueKey('loc-kecamatan-$_level2ActiveParent-$_kecamatan'),
            label: lang.get('District', 'Kecamatan') + requiredSuffix,
            options: _kecamatanOptions,
            value: _kecamatan,
            state: kecamatanState,
            onChanged: _onSelectKecamatan,
          ),
        if (kelurahanState.visible)
          _buildDropdown(
            key: ValueKey('loc-kelurahan-$_kecamatan-$_kelurahan'),
            label: lang.get('Village', 'Kelurahan/Desa') + requiredSuffix,
            options: _kelurahanOptions,
            value: _kelurahan,
            state: kelurahanState,
            onChanged: _onSelectKelurahan,
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _postalController,
          enabled: _provinsi != null,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                lang.get('Postal Code (optional)', 'Kode Pos (opsional)'),
            prefixIcon: const Icon(Icons.local_post_office_outlined),
          ),
        ),
      ],
    );
  }

  // Nama di sumber data SELALU diawali kata "Kabupaten" atau "Kota" (diverifikasi: 416 Kabupaten,
  // 98 Kota, tidak ada pengecualian) -- aman dipisah murni dari prefix nama.
  List<LocationDivision> get _kabupatenOptions =>
      _level2Options.where((d) => d.name.startsWith('Kabupaten')).toList();
  List<LocationDivision> get _kotaOptions =>
      _level2Options.where((d) => d.name.startsWith('Kota')).toList();
}
