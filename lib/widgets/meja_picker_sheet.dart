import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/meja_model.dart';
import '../services/meja_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import 'empty_state.dart';

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
    useSafeArea: true,
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
        final list =
            (body['data'] as List? ?? []).map((e) => Meja.fromJson(e)).toList();
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
          Toast.error(
              context,
              body['error']?.toString() ??
                  'Beberapa meja baru saja terisi, silakan pilih ulang');
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
    final textTheme = Theme.of(context).textTheme;
    final canConfirm =
        !_confirming && _selectedCapacity >= widget.jumlahPelanggan;
    final enough = _selectedCapacity >= widget.jumlahPelanggan;
    // layar pendek (HP landscape): langsung hampir penuh supaya daftar
    // meja tetap kelihatan
    final short = context.isShort;

    return DraggableScrollableSheet(
      initialChildSize: short ? 0.95 : 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 4,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Pilih Meja', style: textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              // kapasitas: pil status (hijau kalau sudah cukup)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: enough ? AppColors.successLight : AppColors.chipBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      enough
                          ? Icons.check_circle_rounded
                          : Icons.people_outline,
                      size: 18,
                      color: enough ? AppColors.successDark : AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kapasitas terpilih: $_selectedCapacity / ${widget.jumlahPelanggan} orang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: enough ? AppColors.successDark : AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading || _confirming ? null : _autoPick,
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text('Acak Otomatis',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (_reservedByMe.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _confirming ? null : _kosongkan,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.event_seat_outlined, size: 18),
                        label: const Text('Kosongkan',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _mejaList.isEmpty
                        ? SingleChildScrollView(
                            controller: scrollController,
                            child: const EmptyState(
                              icon: Icons.table_bar_outlined,
                              title: 'Belum ada meja',
                              description:
                                  'Buat area & meja lewat menu Atur Meja terlebih dahulu.',
                              compact: true,
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _mejaList.length,
                            itemBuilder: (context, index) {
                              final m = _mejaList[index];
                              final selectable = _isSelectable(m);
                              final selected = _selected.contains(m.mejaId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Opacity(
                                  opacity: selectable ? 1 : 0.5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.blueLight
                                          : AppColors.surface,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.blue
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      value: selected,
                                      onChanged:
                                          selectable ? (_) => _toggle(m) : null,
                                      dense: true,
                                      title: Text(
                                        m.mejaName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleSmall,
                                      ),
                                      subtitle: Text(
                                        'Kapasitas ${m.mejaCapacity} orang'
                                        '${selectable ? '' : ' - sedang dipakai'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: canConfirm ? _confirm : null,
                  icon: _confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Konfirmasi'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
