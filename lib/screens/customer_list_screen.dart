import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/customer_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Menu penjual: Daftar Customer. Menampilkan customer milik outlet penjual
/// (tabel customer) dan bisa menambah 1 customer atau banyak sekaligus (bulk).
/// Bulk dikirim lewat Kafka (async) supaya request tidak menunggu.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _api = CustomerApi();
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;
  String _outcode = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _outcode = await Storage.get(AppConstants.outcode) ?? '';
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _api.getAllCustomer('', _outcode);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _customers = ((body['data'] ?? []) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ---------- Tambah 1 customer ----------
  Future<void> _addSingle() async {
    final nameC = TextEditingController();
    final tokoC = TextEditingController();
    final phoneC = TextEditingController();
    final addrC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Tambah Customer'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        content: SizedBox(
          width: dc.dialogMaxWidth(440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameC,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tokoC,
                  decoration: const InputDecoration(
                    labelText: 'Nama Toko',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneC,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telepon',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addrC,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
              ],
            ),
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
    if (ok != true) return;
    if (nameC.text.trim().isEmpty) {
      if (mounted) Toast.error(context, 'Nama customer wajib diisi');
      return;
    }
    final cust = _custMap(nameC.text, tokoC.text, phoneC.text, addrC.text);
    try {
      final resp = await _api.insertCustomer([cust]);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (mounted) Toast.success(context, 'Customer ditambahkan');
        await _load();
      } else {
        _showErr(resp);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
  }

  // ---------- Tambah massal (bulk via Kafka) ----------
  Future<void> _addBulk() async {
    final bulkC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Tambah Massal'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        content: SizedBox(
          width: dc.dialogMaxWidth(480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Text(
                    'Satu customer per baris. Format:\n'
                    'Nama | Telepon | Alamat\n'
                    '(Telepon & Alamat opsional)',
                    style: TextStyle(fontSize: 12, color: AppColors.infoDark),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bulkC,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText:
                        'Budi | 08123 | Jl. Mawar\nSiti\nToko Jaya | 0899',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dc, true),
              child: const Text('Kirim')),
        ],
      ),
    );
    if (ok != true) return;

    final customers = <Map<String, dynamic>>[];
    for (final line in bulkC.text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final parts = t.split('|').map((e) => e.trim()).toList();
      final name = parts.isNotEmpty ? parts[0] : '';
      if (name.isEmpty) continue;
      final phone = parts.length > 1 ? parts[1] : '';
      final addr = parts.length > 2 ? parts[2] : '';
      customers.add(_custMap(name, '', phone, addr));
    }
    if (customers.isEmpty) {
      if (mounted) Toast.error(context, 'Tidak ada baris valid');
      return;
    }
    try {
      final resp = await _api.bulkInsertCustomer(customers);
      if (resp.statusCode == 202 || resp.statusCode == 200) {
        if (mounted) {
          Toast.success(context,
              '${customers.length} customer diantrekan, muncul beberapa saat lagi');
        }
        // beri jeda lalu refresh (insert async lewat Kafka)
        await Future.delayed(const Duration(seconds: 2));
        await _load();
      } else {
        _showErr(resp);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
  }

  Map<String, dynamic> _custMap(
      String name, String toko, String phone, String addr) {
    return {
      "cust_outcode": _outcode,
      "cust_name": name.trim(),
      "cust_outlet_name": toko.trim(),
      "cust_phone": phone.trim(),
      "cust_address": addr.trim(),
      "cust_email": "",
      "cust_status": "ACTIVE",
    };
  }

  void _showErr(resp) {
    String msg = 'Gagal menyimpan';
    try {
      msg = jsonDecode(resp.body)['error'] ?? msg;
    } catch (_) {}
    if (mounted) Toast.error(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final columns = context.columnsFor(minTileWidth: 320, max: 3);
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Daftar Customer',
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ],
        ),
        drawer: const AppDrawer(),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'bulk',
              onPressed: _addBulk,
              backgroundColor: AppColors.tealDark,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Massal'),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'single',
              onPressed: _addSingle,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Tambah'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _customers.isEmpty
                ? ListView(
                    children: const [
                      EmptyState(
                        icon: Icons.contacts_outlined,
                        title: 'Belum ada customer',
                        description:
                            'Tambahkan customer satu per satu (Tambah) atau banyak sekaligus (Massal) lewat tombol di kanan bawah.',
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ContentWidth(
                      child: GridView.builder(
                        padding: EdgeInsets.fromLTRB(pad, pad, pad, 150),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 76,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _customers.length,
                        itemBuilder: (context, i) {
                          final c = _customers[i];
                          final name = (c['cust_name'] ?? '').toString();
                          final toko = (c['cust_outlet_name'] ?? '').toString();
                          final phone = (c['cust_phone'] ?? '').toString();
                          final code = (c['cust_code'] ?? '').toString();
                          return _CustomerTile(
                            name: name,
                            subtitle: [
                              if (toko.isNotEmpty) toko,
                              if (phone.isNotEmpty) phone,
                            ].join(' • '),
                            code: code,
                          );
                        },
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String code;

  const _CustomerTile({
    required this.name,
    required this.subtitle,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.blueLight,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? '-' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall),
                ],
              ),
            ),
            if (code.isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
