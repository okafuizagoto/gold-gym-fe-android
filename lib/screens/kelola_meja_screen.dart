import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/meja_model.dart';
import '../models/outlet_model.dart';
import '../services/meja_api.dart';
import '../services/outlet_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
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
        final list =
            (body['data'] as List? ?? []).map((e) => Meja.fromJson(e)).toList();
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
        content:
            Text('Yakin ingin mengosongkan ${_selected.length} meja terpilih?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
    final pad = context.pagePadding;
    final columns = context.columnsFor(minTileWidth: 300, max: 3);
    final isiCount = _mejaList.where((m) => !m.isKosong).length;

    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Kelola Meja'),
        drawer: const AppDrawer(),
        body: _loadingOutlets
            ? const Center(child: CircularProgressIndicator())
            : ContentWidth(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, pad, pad, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey(_selectedOutcode),
                            initialValue: _selectedOutcode,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Outlet',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                            items: _outlets
                                .map((o) => DropdownMenuItem(
                                      value: o.outlet_code,
                                      child: Text(
                                        o.outlet_name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() => _selectedOutcode = v);
                              _loadMeja();
                            },
                          ),
                          if (_mejaList.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: CheckboxListTile(
                                    value: allSelected,
                                    onChanged: _toggleAll,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Pilih Semua'),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ),
                                Text(
                                  '$isiCount terisi / ${_mejaList.length} meja',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: _loadingMeja
                          ? const Center(child: CircularProgressIndicator())
                          : _mejaList.isEmpty
                              ? const SingleChildScrollView(
                                  child: EmptyState(
                                    icon: Icons.table_bar_rounded,
                                    title: 'Belum ada meja',
                                    description:
                                        'Tambahkan meja lewat menu Atur Meja > Meja & Area.',
                                  ),
                                )
                              : GridView.builder(
                                  padding:
                                      EdgeInsets.fromLTRB(pad, 4, pad, pad),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent: 72,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: _mejaList.length,
                                  itemBuilder: (context, index) {
                                    final m = _mejaList[index];
                                    final checked =
                                        _selected.contains(m.mejaId);
                                    return _MejaCheckTile(
                                      meja: m,
                                      checked: checked,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selected.add(m.mejaId);
                                          } else {
                                            _selected.remove(m.mejaId);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                    ),
                    if (_mejaList.isNotEmpty)
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border:
                              Border(top: BorderSide(color: AppColors.border)),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(pad, 10, pad, 10),
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _selected.isNotEmpty && !_clearing
                                    ? _confirmKosongkan
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                icon: _clearing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(
                                        Icons.cleaning_services_rounded,
                                        size: 20),
                                label: Text(
                                    'Kosongkan Meja (${_selected.length})'),
                              ),
                            ),
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

class _MejaCheckTile extends StatelessWidget {
  final Meja meja;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  const _MejaCheckTile({
    required this.meja,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final kosong = meja.isKosong;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: checked ? AppColors.blue : AppColors.border,
          width: checked ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              Checkbox(value: checked, onChanged: onChanged),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meja.mejaName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall),
                    Text('Kapasitas ${meja.mejaCapacity} orang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kosong ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  kosong ? 'Kosong' : 'Isi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kosong ? AppColors.successDark : AppColors.errorDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
