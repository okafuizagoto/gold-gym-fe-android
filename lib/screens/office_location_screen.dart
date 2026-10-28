import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/staff_attendance_model.dart';
import '../services/staff_api.dart';
import '../utils/geo_location.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Lokasi Kantor (batas lokasi absen staff): ubah titik/radius atau nonaktifkan. Boleh dibuka
/// penjual, dan staff yang diizinkan penjual lewat Akses Staff (menu_key "/lokasi-kantor";
/// backend menegakkan hal yang sama). Berlaku untuk SEMUA staff milik penjual.
class OfficeLocationScreen extends StatefulWidget {
  const OfficeLocationScreen({super.key});

  @override
  State<OfficeLocationScreen> createState() => _OfficeLocationScreenState();
}

class _OfficeLocationScreenState extends State<OfficeLocationScreen> {
  final _api = StaffApi();
  OfficeLocation? _office;
  bool _loading = true;
  bool _savingOffice = false;

  @override
  void initState() {
    super.initState();
    _loadOffice();
  }

  Future<void> _loadOffice() async {
    try {
      final resp = await _api.getOffice();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (mounted) {
          setState(() => _office =
              OfficeLocation.fromJson(body['data'] as Map<String, dynamic>));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  /// Atur/ubah titik kantor + radius. Staff hanya bisa absen di sekitar titik ini.
  Future<void> _setOffice() async {
    final o = _office;
    final nameC = TextEditingController(text: o?.name ?? '');
    final latC = TextEditingController(
        text: o?.configured == true ? o!.lat.toString() : '');
    final lngC = TextEditingController(
        text: o?.configured == true ? o!.lng.toString() : '');
    final radiusC = TextEditingController(text: (o?.radiusM ?? 100).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) {
        var locating = false;
        return StatefulBuilder(
          builder: (dc, setD) => AlertDialog(
            title: const Text('Lokasi Kantor'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff hanya bisa absen masuk dan pulang di sekitar titik ini. Berdirilah di kantor, lalu tekan tombol lokasi. Berlaku untuk SEMUA staff. Koordinat staff tidak disimpan; hanya dipakai untuk menghitung jarak saat absen.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameC,
                    maxLength: 100,
                    decoration: const InputDecoration(
                        labelText: 'Nama kantor (opsional)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: locating
                        ? null
                        : () async {
                            setD(() => locating = true);
                            try {
                              final geo = await getCurrentGeo();
                              latC.text =
                                  (geo['lat'] as double).toStringAsFixed(7);
                              lngC.text =
                                  (geo['lng'] as double).toStringAsFixed(7);
                              if (mounted) {
                                Toast.success(context,
                                    'Titik kantor diisi dari lokasi Anda saat ini');
                              }
                            } catch (e) {
                              if (mounted) {
                                Toast.error(
                                    context,
                                    e is GeoException
                                        ? e.message
                                        : 'Lokasi tidak terbaca');
                              }
                            }
                            setD(() => locating = false);
                          },
                    icon: locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded),
                    label: const Text('Gunakan lokasi saya sekarang'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latC,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Lintang'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lngC,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Bujur'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: radiusC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Radius (meter)',
                      helperText: '20 - 1000 m. Disarankan 100 m.',
                      suffixText: 'm',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dc, false),
                  child: const Text('Batal')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(dc, true),
                  child: const Text('Simpan')),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    final lat = double.tryParse(latC.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(lngC.text.trim().replaceAll(',', '.'));
    final radius = int.tryParse(radiusC.text.trim());
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      if (mounted) {
        Toast.error(context,
            'Titik kantor belum diisi. Tekan "Gunakan lokasi saya sekarang" saat Anda berada di kantor.');
      }
      return;
    }
    if (radius == null || radius < 20 || radius > 1000) {
      if (mounted) Toast.error(context, 'Radius harus antara 20 dan 1000 meter');
      return;
    }
    setState(() => _savingOffice = true);
    try {
      final resp = await _api.setOffice(
          name: nameC.text.trim(), lat: lat, lng: lng, radiusM: radius);
      if (resp.statusCode == 200) {
        if (mounted) {
          Toast.success(context,
              'Lokasi kantor disimpan. Staff hanya bisa absen di sekitar titik ini.');
        }
        await _loadOffice();
      } else {
        String msg = 'Gagal menyimpan';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _savingOffice = false);
    }
  }

  /// Nonaktifkan batas lokasi = kosongkan lokasi kantor; staff kembali bisa absen dari mana saja.
  Future<void> _disableOffice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Nonaktifkan batas lokasi?'),
        content: const Text(
            'Lokasi kantor akan dihapus. Setelah itu SEMUA staff bisa absen masuk dan pulang dari mana saja. Anda bisa mengaturnya lagi kapan saja.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: const Text('Batal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dc, true),
              child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _savingOffice = true);
    try {
      final resp = await _api.clearOffice();
      if (resp.statusCode == 200) {
        if (mounted) {
          Toast.success(context,
              'Batas lokasi dinonaktifkan. Staff bisa absen dari mana saja.');
        }
        await _loadOffice();
      } else {
        String msg = 'Gagal menonaktifkan';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _savingOffice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final o = _office;
    final configured = o?.configured == true;
    return PrivateRoute(
      staffMenuKey: '/lokasi-kantor',
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Lokasi Kantor'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: configured
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              configured
                                  ? Icons.place_rounded
                                  : Icons.location_off_rounded,
                              color: configured
                                  ? AppColors.successDark
                                  : AppColors.warningDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              configured
                                  ? 'Absen dibatasi di ${o!.name.isEmpty ? 'kantor' : o.name}'
                                  : 'Batas lokasi nonaktif',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          configured
                              ? 'Radius ${o!.radiusM} m  \u2022  ${o.lat.toStringAsFixed(5)}, ${o.lng.toStringAsFixed(5)}'
                              : 'Lokasi kantor belum diatur: staff bisa absen dari mana saja.',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Berlaku untuk SEMUA staff. Staff hanya bisa absen masuk dan pulang di sekitar titik kantor. Koordinat staff tidak disimpan; hanya dipakai untuk menghitung jarak saat absen.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _savingOffice ? null : _setOffice,
                      icon: const Icon(Icons.edit_location_alt_rounded),
                      label: Text(configured ? 'Ubah lokasi kantor' : 'Atur lokasi kantor'),
                    ),
                  ),
                  if (configured) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _savingOffice ? null : _disableOffice,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error)),
                        icon: const Icon(Icons.location_off_rounded),
                        label: const Text('Nonaktifkan batas lokasi'),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
