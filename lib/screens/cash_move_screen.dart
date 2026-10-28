import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/cash_day_model.dart';
import '../providers/language_provider.dart';
import '../services/cashier_shift_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';
import '../widgets/tour_target.dart';

/// Tarik Kas (incoming=false, uang KELUAR laci) dan Tambah Kas (incoming=true, uang MASUK laci) -- padanan
/// pages/tarik-kas dan pages/tambah-kas di web. Pencatat diambil server dari akun yang login; catatan tidak bisa
/// diubah/dihapus. Penjual selalu boleh; staff hanya bila diizinkan penjual (menu_key "/tarik-kas" / "/tambah-kas").
/// "Alasan" di sini = alasan transaksi kas ini, BERBEDA dari alasan selisih serah-terima saat buka sesi.
class CashMoveScreen extends StatefulWidget {
  final bool incoming;
  const CashMoveScreen({super.key, required this.incoming});

  @override
  State<CashMoveScreen> createState() => _CashMoveScreenState();
}

class _CashMoveScreenState extends State<CashMoveScreen> {
  final _api = CashierShiftApi();
  final _amountC = TextEditingController();
  final _reasonC = TextEditingController();
  late String _kind = _kinds.first[0] as String;
  String get _label => widget.incoming ? 'Tambah Kas' : 'Tarik Kas';
  List<List<dynamic>> get _kinds =>
      cashMoveKinds.where((k) => (k[2] as bool) == widget.incoming).toList();
  String _outcode = '';
  bool _loading = true;
  bool _saving = false;
  List<CashMove> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountC.dispose();
    _reasonC.dispose();
    super.dispose();
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (_outcode.isNotEmpty) {
      try {
        final r = await _api.cashMoves(_outcode, incoming: widget.incoming, date: _today());
        if (r.statusCode == 200) {
          _rows = ((jsonDecode(r.body)['data'] ?? []) as List)
              .map((e) => CashMove.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else if (mounted) {
          Toast.error(context, _err(r.body, 'Gagal memuat catatan $_label'));
        }
      } catch (_) {
        if (mounted) Toast.error(context, 'Gagal memuat catatan $_label');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _err(String body, String fallback) {
    try {
      return jsonDecode(body)['error'] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountC.text.trim()) ?? 0;
    if (_outcode.isEmpty) {
      Toast.error(context, 'Pilih outlet terlebih dahulu');
      return;
    }
    if (amount <= 0) {
      Toast.error(context, 'Jumlah harus lebih dari 0');
      return;
    }
    if (_reasonC.text.trim().length < 3) {
      Toast.error(context, 'Alasan wajib diisi');
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await _api.addCashMove(_outcode, _kind, amount, _reasonC.text.trim());
      if (r.statusCode == 200) {
        if (mounted) Toast.success(context, '$_label tercatat');
        _amountC.clear();
        _reasonC.clear();
        await _load();
      } else if (mounted) {
        Toast.error(context, _err(r.body, 'Gagal mencatat'));
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _row(CashMove m) {
    final incoming = cashMoveIsIncoming(m.kind);
    final color = incoming ? Colors.blue.shade700 : Colors.red.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cashMoveKindLabel(m.kind)} · ${m.by}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    '${m.byRole == 'SELLER' ? 'Penjual' : 'Staff'} · ${m.time} · ${m.reason}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Text('${incoming ? '+' : '-'}${TextFormatter.formatRupiah(m.amount)}',
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final pad = context.pagePadding;
    return PrivateRoute(
      staffMenuKey: widget.incoming ? '/tambah-kas' : '/tarik-kas',
      child: Scaffold(
        appBar: AppBarCustom(title: _label),
        drawer: const AppDrawer(),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              Text(
                  widget.incoming
                      ? 'Catat uang yang MASUK ke laci di luar penjualan (tambah modal dll). Pencatat tersimpan otomatis.'
                      : 'Catat uang yang KELUAR dari laci di luar penjualan (tarik owner, setor bank, pengeluaran). Pencatat tersimpan otomatis.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _kind,
                        decoration: const InputDecoration(labelText: 'Jenis'),
                        items: [
                          for (final k in _kinds)
                            DropdownMenuItem(
                                value: k[0] as String, child: Text('${k[1]}')),
                        ],
                        onChanged: (v) => setState(() => _kind = v ?? _kind),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reasonC,
                        maxLength: 255,
                        decoration: InputDecoration(
                            labelText: widget.incoming
                                ? 'Alasan tambah kas (wajib)'
                                : 'Alasan tarik kas (wajib)',
                            hintText: widget.incoming
                                ? 'mis. modal tambahan dari pemilik'
                                : 'mis. kas membengkak, disetor ke bank BCA'),
                      ),
                      TourTarget(
                        id: 'cash-move-save',
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('CATAT'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                          'Catatan tidak bisa diubah atau dihapus. Jika salah input, buat catatan lawan (mis. salah tarik → catat Tambah Kas dengan jumlah sama).',
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Catatan $_label hari ini',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      if (_loading)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()))
                      else if (_rows.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('Belum ada catatan $_label hari ini.'))
                      else
                        for (final m in _rows) ...[const Divider(height: 1), _row(m)],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
