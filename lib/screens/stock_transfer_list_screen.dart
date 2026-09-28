import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/stock_transfer_model.dart';
import '../services/stock_transfer_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import 'stock_transfer_create_screen.dart';
import 'stock_transfer_detail_screen.dart';

Color transferColor(String status) {
  switch (status) {
    case TransferStatus.diterima:
      return Colors.green.shade700;
    case TransferStatus.dikirim:
      return Colors.blue.shade700;
    case TransferStatus.dibatalkan:
      return AppColors.error;
    default:
      return Colors.orange.shade800;
  }
}

/// Riwayat transfer stok outlet aktif. Padanan pages/transfer-stok (Next.js).
class StockTransferListScreen extends StatefulWidget {
  const StockTransferListScreen({super.key});

  @override
  State<StockTransferListScreen> createState() =>
      _StockTransferListScreenState();
}

class _StockTransferListScreenState extends State<StockTransferListScreen> {
  final _api = StockTransferApi();
  String _direction = ''; // '' semua | out | in
  String _outcode = '';
  bool _isStaff = false;
  bool _loading = true;
  List<StockTransfer> _rows = [];
  TransferPermission? _perm;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    final role = await Storage.get(AppConstants.userRoleKey) ?? '';
    if (mounted) {
      setState(() {
        _outcode = outcode;
        _isStaff = role == AppConstants.roleStaff;
      });
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _api.list(outcode: _outcode, direction: _direction);
      final perm = await _api.myPermission();
      if (rows == null && mounted) {
        Toast.error(context, 'Gagal memuat riwayat transfer');
      }
      if (mounted) {
        setState(() {
          _rows = rows ?? [];
          _perm = perm;
        });
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat riwayat transfer');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate =
        !_isStaff || (_perm != null && _perm!.sendLevel != TransferLevel.none);
    final pending = _rows.where((r) => r.pendingAction != null).length;
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Transfer Stok'),
        drawer: const AppDrawer(),
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                onPressed: () => _open(const StockTransferCreateScreen()),
                icon: const Icon(Icons.add),
                label: const Text('Buat Transfer'),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '', label: Text('Semua')),
                  ButtonSegment(value: 'out', label: Text('Keluar')),
                  ButtonSegment(value: 'in', label: Text('Masuk')),
                ],
                selected: {_direction},
                onSelectionChanged: (s) {
                  setState(() => _direction = s.first);
                  _load();
                },
              ),
            ),
            if (!_isStaff && pending > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Chip(
                    label: Text('$pending transfer menunggu persetujuan Anda')),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _rows.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 80),
                              EmptyState(
                                title: 'Belum ada transfer',
                                description:
                                    'Transfer stok antar outlet akan muncul di sini.',
                              ),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => _tile(_rows[i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(StockTransfer r) {
    final outgoing = r.fromOutcode == _outcode;
    return Card(
      child: ListTile(
        onTap: () => _open(StockTransferDetailScreen(transferId: r.id)),
        title: Text(r.number, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${r.fromName} → ${r.toName}\n${r.createdAt == null ? '-' : TextFormatter.formatDate(r.createdAt!)} · ${r.createdByName} · ${outgoing ? 'keluar' : 'masuk'}'),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(r.status,
                style: TextStyle(
                    color: transferColor(r.status), fontWeight: FontWeight.w700)),
            if (r.pendingAction != null)
              Text('Menunggu persetujuan',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
