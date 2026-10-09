import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/location_model.dart';
import '../providers/language_provider.dart';
import '../services/location_api.dart';

/// Dropdown berjenjang lokasi (negara disembunyikan selama cuma Indonesia yang didukung -- lihat
/// rancangan deploy-notes/.../30-RANCANGAN-FITUR-LOKASI-OUTLET.md §6).
///
/// 2026-10-09: Kabupaten & Kota SEKARANG field independen (state terpisah) -- sebelumnya keduanya
/// menulis ke satu slot `_selected[1]` yang sama, jadi memilih salah satu membuat field lainnya
/// tampak "kosong/terhapus" di layar -- membingungkan meski secara data memang benar keduanya
/// sejajar (satu wilayah cuma salah satu, lihat contoh Kabupaten Tangerang vs Kota Tangerang
/// Selatan, keduanya anak langsung Provinsi Banten, bukan satu di dalam yang lain). Kecamatan
/// mengikuti SIAPAPUN (Kabupaten atau Kota) yang terakhir dipilih sebagai induknya. Saat dikirim ke
/// backend, division_level2_id = kabupaten ?? kota (satu kolom yang sama).
///
/// Urutan tampilan (permintaan user, 2026-10-09): Provinsi, Kabupaten, Kecamatan, Kota,
/// Kelurahan/Desa (otomatis sembunyi kalau belum ada data), Kode Pos.
///
/// Validasi wajib/opsional per level: tiap level WAJIB diisi HANYA KALAU benar-benar ada opsi yang
/// bisa dipilih (query sukses, bukan gagal/error, dan hasilnya tidak kosong). Level tanpa data
/// (mis. Kelurahan/Desa belum di-seed) otomatis tidak ditampilkan sehingga otomatis opsional.
/// [onValidityChange] memberi tahu parent apakah semua level yang punya data sudah terisi.
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

  // "Loaded": true setelah query level itu SELESAI (sukses), terlepas hasilnya kosong atau tidak
  // -- membedakan "belum sempat dicek" vs "sudah dicek, memang tidak ada data".
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
      // gagal muat (error jaringan/server) -- JANGAN tandai loaded, supaya tidak dianggap "memang
      // tidak ada data" padahal cuma gagal query.
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
      level2Id: _kabupaten ?? _kota,
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
      complete =
          false; // level2 belum selesai dicek -- belum bisa dianggap lengkap
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDropdown(
          key: const ValueKey('loc-provinsi'),
          label: lang.get('Province', 'Provinsi'),
          options: _provinsiOptions,
          value: _provinsi,
          loading: false,
          onChanged: _onSelectProvinsi,
        ),
        if (_provinsi != null &&
            (_kabupatenOptions.isNotEmpty || _loadingLevel2))
          _buildDropdown(
            key: ValueKey('loc-kabupaten-$_provinsi-$_kabupaten'),
            label: lang.get('Regency', 'Kabupaten') + requiredSuffix,
            options: _kabupatenOptions,
            value: _kabupaten,
            loading: _loadingLevel2,
            onChanged: _onSelectKabupaten,
          ),
        if (_provinsi != null &&
            _level2ActiveParent != null &&
            (_kecamatanOptions.isNotEmpty || _loadingKecamatan))
          _buildDropdown(
            key: ValueKey('loc-kecamatan-$_level2ActiveParent-$_kecamatan'),
            label: lang.get('District', 'Kecamatan') + requiredSuffix,
            options: _kecamatanOptions,
            value: _kecamatan,
            loading: _loadingKecamatan,
            onChanged: _onSelectKecamatan,
          ),
        if (_provinsi != null && (_kotaOptions.isNotEmpty || _loadingLevel2))
          _buildDropdown(
            key: ValueKey('loc-kota-$_provinsi-$_kota'),
            label: lang.get('City', 'Kota') + requiredSuffix,
            options: _kotaOptions,
            value: _kota,
            loading: _loadingLevel2,
            onChanged: _onSelectKota,
          ),
        if (_kecamatan != null &&
            (_kelurahanOptions.isNotEmpty || _loadingKelurahan))
          _buildDropdown(
            key: ValueKey('loc-kelurahan-$_kecamatan-$_kelurahan'),
            label: lang.get('Village', 'Kelurahan/Desa') + requiredSuffix,
            options: _kelurahanOptions,
            value: _kelurahan,
            loading: _loadingKelurahan,
            onChanged: _onSelectKelurahan,
          ),
        if (_provinsi != null) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _postalController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  lang.get('Postal Code (optional)', 'Kode Pos (opsional)'),
              prefixIcon: const Icon(Icons.local_post_office_outlined),
            ),
          ),
        ],
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
