import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/meja_model.dart';
import '../services/meja_api.dart';
import '../utils/toast.dart';

class MejaSelectionResult {
  final List<int> ids;
  final List<String> names;
  MejaSelectionResult(this.ids, this.names);
}

/// Bottom sheet pilih meja POS: manual (tap, boleh gabung >1 meja sampai
/// kapasitas cukup) atau "Acak Otomatis". Kalau [currentMejaIds] tidak
/// kosong, itu dianggap meja yang SUDAH direservasi kasir untuk sesi ini
/// (mis. re-open untuk edit pilihan) -- tetap bisa dipilih/dilepas, dan
/// tombol "Kosongkan" akan melepas semuanya sekaligus.
Future<MejaSelectionResult?> showMejaPickerSheet(
  BuildContext context, {
  required String outcode,
  required int jumlahPelanggan,
  required List<int> currentMejaIds,
}) {
  return showModalBottomSheet<MejaSelectionResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _MejaPickerSheetBody(
      outcode: outcode,
      jumlahPelanggan: jumlahPelanggan,
      initialMejaIds: currentMejaIds,
    ),
  );
}

class _MejaPickerSheetBody extends StatefulWidget {
  final String outcode;
  final int jumlahPelanggan;
  final List<int> initialMejaIds;

  const _MejaPickerSheetBody({
    required this.outcode,
    required this.jumlahPelanggan,
    required this.initialMejaIds,
  });

  @override
  State<_MejaPickerSheetBody> createState() => _MejaPickerSheetBodyState();
}

class _MejaPickerSheetBodyState extends State<_MejaPickerSheetBody> {
  final _mejaApi = MejaApi();

  bool _loading = true;
  bool _confirming = false;
  List<Meja> _mejaList = [];
  late Set<int> _selected;
  late List<int> _reservedByMe;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialMejaIds};
    _reservedByMe = [...widget.initialMejaIds];
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _mejaApi.getMeja(widget.outcode);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List? ?? [])
            .map((e) => Meja.fromJson(e))
            .toList();
        setState(() {
          _mejaList = list;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Meja yang boleh dipilih: KOSONG, atau sudah direservasi kasir di sesi
  /// ini (_reservedByMe) -- bukan milik sesi/kasir lain.
  bool _isSelectable(Meja m) => m.isKosong || _reservedByMe.contains(m.mejaId);

  int get _selectedCapacity => _mejaList
      .where((m) => _selected.contains(m.mejaId))
      .fold(0, (sum, m) => sum + m.mejaCapacity);

  void _toggle(Meja m) {
    if (!_isSelectable(m)) return;
    setState(() {
      if (_selected.contains(m.mejaId)) {
        _selected.remove(m.mejaId);
      } else {
        _selected.add(m.mejaId);
      }
    });
  }

  void _autoPick() {
    final available = _mejaList.where(_isSelectable).toList()
      ..sort((a, b) => a.mejaCapacity.compareTo(b.mejaCapacity));

    // 1. Satu meja cukup sendirian, kapasitas terkecil yang memenuhi.
    for (final m in available) {
      if (m.mejaCapacity >= widget.jumlahPelanggan) {
        setState(() => _selected = {m.mejaId});
        return;
      }
    }

    // 2. Gabungkan dari kapasitas terbesar dulu (minimalkan jumlah meja).
    final byCapacityDesc = [...available]
      ..sort((a, b) => b.mejaCapacity.compareTo(a.mejaCapacity));
    final picked = <int>{};
    int sum = 0;
    for (final m in byCapacityDesc) {
      if (sum >= widget.jumlahPelanggan) break;
      picked.add(m.mejaId);
      sum += m.mejaCapacity;
    }

    if (sum < widget.jumlahPelanggan) {
      Toast.error(context, 'Kapasitas meja kosong tidak mencukupi');
      return;
    }
    setState(() => _selected = picked);
  }

  Future<void> _kosongkan() async {
    if (_reservedByMe.isEmpty) return;
    setState(() => _confirming = true);
    try {
      await _mejaApi.releaseMeja(widget.outcode, _reservedByMe);
    } catch (_) {
      // best-effort
    }
    if (!mounted) return;
    setState(() {
      _reservedByMe = [];
      _selected = {};
      _confirming = false;
    });
    await _load();
  }

  Future<void> _confirm() async {
    if (_selectedCapacity < widget.jumlahPelanggan) return;

    setState(() => _confirming = true);

    final toReserve =
        _selected.where((id) => !_reservedByMe.contains(id)).toList();
    final toRelease =
        _reservedByMe.where((id) => !_selected.contains(id)).toList();

    try {
      if (toReserve.isNotEmpty) {
        final res = await _mejaApi.reserveMeja(widget.outcode, toReserve);
        if (res.statusCode != 200) {
          if (!mounted) return;
          final body = jsonDecode(res.body);
          Toast.error(context,
              body['error']?.toString() ?? 'Beberapa meja baru saja terisi, silakan pilih ulang');
          setState(() => _confirming = false);
          await _load();
          return;
        }
      }
      if (toRelease.isNotEmpty) {
        await _mejaApi.releaseMeja(widget.outcode, toRelease);
      }
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Gagal menyimpan pilihan meja');
      setState(() => _confirming = false);
      return;
    }

    if (!mounted) return;
    final names = _mejaList
        .where((m) => _selected.contains(m.mejaId))
        .map((m) => m.mejaName)
        .toList();
    Navigator.pop(context, MejaSelectionResult(_selected.toList(), names));
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        !_confirming && _selectedCapacity >= widget.jumlahPelanggan;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pilih Meja',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text('Kapasitas terpilih: $_selectedCapacity / ${widget.jumlahPelanggan}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading || _confirming ? null : _autoPick,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Acak Otomatis'),
                    ),
                  ),
                  if (_reservedByMe.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _confirming ? null : _kosongkan,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.event_seat_outlined),
                        label: const Text('Kosongkan'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _mejaList.length,
                        itemBuilder: (context, index) {
                          final m = _mejaList[index];
                          final selectable = _isSelectable(m);
                          final selected = _selected.contains(m.mejaId);
                          return Opacity(
                            opacity: selectable ? 1 : 0.4,
                            child: CheckboxListTile(
                              value: selected,
                              onChanged: selectable ? (_) => _toggle(m) : null,
                              title: Text(m.mejaName),
                              subtitle: Text('Kapasitas ${m.mejaCapacity} orang'
                                  '${selectable ? '' : ' - sedang dipakai'}'),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: canConfirm ? _confirm : null,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _confirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Konfirmasi'),
              ),
            ],
          ),
        );
      },
    );
  }
}
