import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/meja_model.dart';
import '../models/outlet_model.dart';
import '../services/meja_api.dart';
import '../services/outlet_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Layar "Kelola Meja": lihat status semua meja per outlet, pilih satu/
/// semua, lalu "Kosongkan Meja" untuk meja yang pelanggannya sudah pergi.
class KelolaMejaScreen extends StatefulWidget {
  const KelolaMejaScreen({super.key});

  @override
  State<KelolaMejaScreen> createState() => _KelolaMejaScreenState();
}

class _KelolaMejaScreenState extends State<KelolaMejaScreen> {
  final _mejaApi = MejaApi();
  final _outletsApi = OutletsApi();

  List<OutletResponse> _outlets = [];
  String? _selectedOutcode;
  bool _loadingOutlets = true;

  bool _loadingMeja = false;
  List<Meja> _mejaList = [];
  final Set<int> _selected = {};
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    final activeOutcode = await Storage.get(AppConstants.outcode) ?? '';
    try {
      final response = await _outletsApi.getAllOutlet('', '', 0, 0);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List? ?? [])
            .map((e) => OutletResponse.fromJson(e))
            .toList();
        setState(() {
          _outlets = list;
          _selectedOutcode = list.any((o) => o.outlet_code == activeOutcode)
              ? activeOutcode
              : (list.isNotEmpty ? list.first.outlet_code : null);
          _loadingOutlets = false;
        });
        if (_selectedOutcode != null) _loadMeja();
      } else {
        setState(() => _loadingOutlets = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOutlets = false);
    }
  }

  Future<void> _loadMeja() async {
    if (_selectedOutcode == null) return;
    setState(() {
      _loadingMeja = true;
      _selected.clear();
    });
    try {
      final response = await _mejaApi.getMeja(_selectedOutcode!);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List? ?? [])
            .map((e) => Meja.fromJson(e))
            .toList();
        setState(() {
          _mejaList = list;
          _loadingMeja = false;
        });
      } else {
        setState(() => _loadingMeja = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMeja = false);
    }
  }

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selected
          ..clear()
          ..addAll(_mejaList.map((m) => m.mejaId));
      } else {
        _selected.clear();
      }
    });
  }

  Future<void> _confirmKosongkan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kosongkan Meja'),
        content: Text(
            'Yakin ingin mengosongkan ${_selected.length} meja terpilih?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearing = true);
    try {
      final response =
          await _mejaApi.releaseMeja(_selectedOutcode!, _selected.toList());
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Meja berhasil dikosongkan');
        await _loadMeja();
      } else {
        Toast.error(context, 'Gagal mengosongkan meja');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal mengosongkan meja');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _mejaList.isNotEmpty && _selected.length == _mejaList.length;

    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Kelola Meja'),
        drawer: const AppDrawer(),
        body: _loadingOutlets
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedOutcode,
                      decoration: const InputDecoration(
                        labelText: 'Outlet',
                        border: OutlineInputBorder(),
                      ),
                      items: _outlets
                          .map((o) => DropdownMenuItem(
                                value: o.outlet_code,
                                child: Text(o.outlet_name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedOutcode = v);
                        _loadMeja();
                      },
                    ),
                  ),
                  if (_mejaList.isNotEmpty)
                    CheckboxListTile(
                      value: allSelected,
                      onChanged: _toggleAll,
                      title: const Text('Pilih Semua'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  Expanded(
                    child: _loadingMeja
                        ? const Center(child: CircularProgressIndicator())
                        : _mejaList.isEmpty
                            ? const Center(child: Text('Belum ada meja.'))
                            : ListView.builder(
                                itemCount: _mejaList.length,
                                itemBuilder: (context, index) {
                                  final m = _mejaList[index];
                                  return CheckboxListTile(
                                    value: _selected.contains(m.mejaId),
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selected.add(m.mejaId);
                                        } else {
                                          _selected.remove(m.mejaId);
                                        }
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(m.mejaName),
                                    subtitle:
                                        Text('Kapasitas ${m.mejaCapacity} orang'),
                                    secondary: Chip(
                                      label: Text(m.isKosong ? 'Kosong' : 'Isi'),
                                      backgroundColor: m.isKosong
                                          ? Colors.green[100]
                                          : Colors.red[100],
                                    ),
                                  );
                                },
                              ),
                  ),
                  if (_mejaList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selected.isNotEmpty && !_clearing
                              ? _confirmKosongkan
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _clearing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Kosongkan Meja (${_selected.length})'),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
