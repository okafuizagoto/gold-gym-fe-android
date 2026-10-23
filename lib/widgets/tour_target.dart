import 'package:flutter/material.dart';

/// Penanda tombol/area yang bisa disorot Panduan Penggunaan (2026-10-23) -- padanan atribut
/// `data-tour-id` di gold-gym-fe-next-js-ts. Pakai pembungkus (bukan GlobalKey) supaya layar yang
/// sama boleh tertumpuk di navigator (mis. tour membuka /penjualan di atas /penjualan) tanpa
/// error GlobalKey ganda; kalau id yang sama terdaftar dua kali, yang terakhir (paling atas) dipakai.
class TourTarget extends StatefulWidget {
  final String id;
  final Widget child;

  /// false = tidak didaftarkan (mis. hanya baris pertama sebuah daftar yang disorot).
  final bool enabled;
  const TourTarget(
      {super.key, required this.id, required this.child, this.enabled = true});

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) TourTargets._register(widget.id, this);
  }

  @override
  void dispose() {
    if (widget.enabled) TourTargets._unregister(widget.id, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TourTargets {
  TourTargets._();

  static final Map<String, List<_TourTargetState>> _byId = {};

  static void _register(String id, _TourTargetState s) =>
      (_byId[id] ??= []).add(s);

  static void _unregister(String id, _TourTargetState s) {
    _byId[id]?.remove(s);
    if (_byId[id]?.isEmpty ?? false) _byId.remove(id);
  }

  /// Context target `id` yang sedang tampil (null = belum/tidak ada di layar).
  static BuildContext? contextOf(String id) {
    final list = _byId[id];
    if (list == null) return null;
    for (final s in list.reversed) {
      if (s.mounted) return s.context;
    }
    return null;
  }
}
