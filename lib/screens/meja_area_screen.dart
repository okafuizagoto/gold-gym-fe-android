import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/area_model.dart';
import '../models/meja_model.dart';
import '../models/outlet_model.dart';
import '../services/area_api.dart';
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
import '../widgets/segmented_tabs.dart';
import '../config/routes.dart';
import '../widgets/tour_target.dart';
import '../utils/tour_demo.dart';

/// Layar utama "Meja & Area": dropdown outlet (default outlet yang
/// sedang aktif) + 2 tab (Meja / Area), masing-masing dengan tombol tambah.
class MejaAreaScreen extends StatefulWidget {
  const MejaAreaScreen({super.key});

  @override
  State<MejaAreaScreen> createState() => _MejaAreaScreenState();
}

class _MejaAreaScreenState extends State<MejaAreaScreen> {
  final _outletsApi = OutletsApi();

  List<OutletResponse> _outlets = [];
  String? _selectedOutcode;
  bool _loadingOutlets = true;
  int _tab = 0;

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
          // diutamakan outlet yang sedang aktif dipilih user
          _selectedOutcode = list.any((o) => o.outlet_code == activeOutcode)
              ? activeOutcode
              : (list.isNotEmpty ? list.first.outlet_code : null);
          _loadingOutlets = false;
        });
      } else {
        setState(() => _loadingOutlets = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOutlets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return PrivateRoute(
      sellerOnly: true,
      staffMenuKey: '/meja-area',
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Meja & Area'),
        drawer: const AppDrawer(),
        body: _loadingOutlets
            ? const Center(child: CircularProgressIndicator())
            : ContentWidth(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
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
                            onChanged: (v) =>
                                setState(() => _selectedOutcode = v),
                          ),
                          const SizedBox(height: 12),
                          SegmentedTabs<int>(
                            value: _tab,
                            onChanged: (v) => setState(() => _tab = v),
                            tabs: const [
                              SegmentedTab(
                                  value: 0,
                                  label: 'Meja',
                                  icon: Icons.table_bar_rounded),
                              SegmentedTab(
                                  value: 1,
                                  label: 'Area',
                                  icon: Icons.map_outlined),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _selectedOutcode == null
                          ? TourDemo.when(
                              demo: () => SingleChildScrollView(
                                child: TourDemoBlock(
                                  child: Column(
                                    children: [
                                      for (final n in const [
                                        'Meja Contoh 1',
                                        'Meja Contoh 2'
                                      ])
                                        Card(
                                          child: ListTile(
                                            leading: const Icon(
                                                Icons.table_bar_rounded),
                                            title: Text(n,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            subtitle: const Text(
                                                'Kapasitas 4 orang - Kosong'),
                                          ),
                                        ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TourTarget(
                                          id: 'meja-add',
                                          child: ElevatedButton.icon(
                                            onPressed: null,
                                            icon: const Icon(Icons.add_rounded),
                                            label: const Text('Tambah Meja'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              normal: () => const SingleChildScrollView(
                                child: EmptyState(
                                  icon: Icons.storefront_outlined,
                                  title: 'Belum ada outlet',
                                  description:
                                      'Buat outlet dulu di menu Ganti Outlet > New Outlet.',
                                ),
                              ),
                            )
                          : IndexedStack(
                              index: _tab,
                              children: [
                                _MejaTabView(
                                    key: ValueKey('meja-$_selectedOutcode'),
                                    outcode: _selectedOutcode!),
                                _AreaTabView(
                                    key: ValueKey('area-$_selectedOutcode'),
                                    outcode: _selectedOutcode!),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MejaTabView extends StatefulWidget {
  final String outcode;
  const _MejaTabView({super.key, required this.outcode});

  @override
  State<_MejaTabView> createState() => _MejaTabViewState();
}

class _MejaTabViewState extends State<_MejaTabView> {
  final _mejaApi = MejaApi();
  final _areaApi = AreaApi();
  bool _loading = true;
  List<Meja> _mejaList = [];
  List<Area> _areaList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait(
          [_mejaApi.getMeja(widget.outcode), _areaApi.getAreas(widget.outcode)]);
      if (!mounted) return;
      final mejaResp = results[0];
      final areaResp = results[1];
      final list = mejaResp.statusCode == 200
          ? (jsonDecode(mejaResp.body)['data'] as List? ?? [])
              .map((e) => Meja.fromJson(e))
              .toList()
          : <Meja>[];
      final areas = areaResp.statusCode == 200
          ? (jsonDecode(areaResp.body)['data'] as List? ?? [])
              .map((e) => Area.fromJson(e))
              .toList()
          : <Area>[];
      setState(() {
        _mejaList = list;
        _areaList = areas;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tambah() async {
    final result = await Navigator.pushNamed(context, AppRoutes.tambahMeja);
    if (result == true) _load();
  }

  // 2026-10-21 (porting dari web pages/meja-area/index.tsx): edit nama/
  // kapasitas/area & hapus meja, dipanggil dari ikon di tiap kartu.
  Future<void> _editMeja(Meja m) async {
    final nameController = TextEditingController(text: m.mejaName);
    final capacityController =
        TextEditingController(text: m.mejaCapacity.toString());
    int? areaId = m.mejaAreaId;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Meja'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama/Nomor Meja'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Kapasitas (orang)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: areaId,
                decoration: const InputDecoration(labelText: 'Area'),
                items: _areaList
                    .map((a) => DropdownMenuItem(
                          value: a.areaId,
                          child: Text(
                              '${a.areaName} (${a.areaType == "INDOOR" ? "Indoor" : "Outdoor"})'),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => areaId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final capacity =
                          int.tryParse(capacityController.text) ?? 0;
                      if (nameController.text.trim().isEmpty ||
                          areaId == null ||
                          capacity < 1) {
                        Toast.error(dialogContext,
                            'Lengkapi nama, kapasitas (minimal 1), dan area meja');
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final response = await _mejaApi.updateMeja(
                            widget.outcode,
                            m.mejaId,
                            nameController.text.trim(),
                            capacity,
                            areaId!);
                        if (!mounted) return;
                        if (response.statusCode == 200) {
                          Navigator.pop(dialogContext);
                          Toast.success(context, 'Meja diperbarui');
                          _load();
                        } else {
                          setDialogState(() => saving = false);
                          Toast.error(dialogContext, 'Gagal memperbarui meja');
                        }
                      } catch (_) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          Toast.error(dialogContext, 'Gagal memperbarui meja');
                        }
                      }
                    },
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMeja(Meja m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Meja'),
        content: Text(
            'Hapus meja "${m.mejaName}"? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await _mejaApi.deleteMeja(widget.outcode, m.mejaId);
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Meja dihapus');
        _load();
      } else {
        Toast.error(context, 'Gagal menghapus meja');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menghapus meja');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final columns = context.columnsFor(minTileWidth: 340, max: 3);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _mejaList.isEmpty
                  ? ListView(
                      children: [
                        if (TourDemo.running.value)
                          TourDemoBlock(
                            child: Column(
                              children: [
                                const Card(
                                  child: ListTile(
                                    leading: Icon(Icons.table_bar_rounded),
                                    title: Text('Meja Contoh 1',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    subtitle:
                                        Text('Kapasitas 4 orang - Kosong'),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TourTarget(
                                    id: 'meja-add',
                                    child: ElevatedButton.icon(
                                      onPressed: null,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Tambah Meja'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                        EmptyState(
                          icon: Icons.table_bar_rounded,
                          title: 'Belum ada meja',
                          description:
                              'Tambahkan meja satu per satu atau banyak sekaligus dengan pola nama (A1, A2, ...).',
                          action: ElevatedButton.icon(
                            onPressed: _tambah,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Tambah Meja'),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 80,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _mejaList.length,
                      itemBuilder: (context, index) {
                        final m = _mejaList[index];
                        return _EntityTile(
                          icon: Icons.table_bar_rounded,
                          title: m.mejaName,
                          subtitle: 'Kapasitas ${m.mejaCapacity} orang',
                          trailing: _StatusPill(
                            label: m.isKosong ? 'Kosong' : 'Isi',
                            positive: m.isKosong,
                          ),
                          onEdit: () => _editMeja(m),
                          onDelete: () => _deleteMeja(m),
                        );
                      },
                    ),
            ),
      floatingActionButton: _mejaList.isEmpty
          ? null
          : TourTarget(
              id: 'meja-add',
              child: FloatingActionButton.extended(
                onPressed: _tambah,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Meja'),
              )),
    );
  }
}

class _AreaTabView extends StatefulWidget {
  final String outcode;
  const _AreaTabView({super.key, required this.outcode});

  @override
  State<_AreaTabView> createState() => _AreaTabViewState();
}

class _AreaTabViewState extends State<_AreaTabView> {
  final _areaApi = AreaApi();
  bool _loading = true;
  List<Area> _areaList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _areaApi.getAreas(widget.outcode);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list =
            (body['data'] as List? ?? []).map((e) => Area.fromJson(e)).toList();
        setState(() {
          _areaList = list;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tambah() async {
    final result = await Navigator.pushNamed(context, AppRoutes.tambahArea);
    if (result == true) _load();
  }

  // 2026-10-21 (porting dari web pages/meja-area/index.tsx): edit nama/tipe
  // & hapus area, dipanggil dari ikon di tiap kartu.
  Future<void> _editArea(Area a) async {
    final nameController = TextEditingController(text: a.areaName);
    String areaType = a.areaType.isEmpty ? 'INDOOR' : a.areaType;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Area'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama Area'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: areaType,
                decoration: const InputDecoration(labelText: 'Tipe'),
                items: const [
                  DropdownMenuItem(value: 'INDOOR', child: Text('Indoor')),
                  DropdownMenuItem(value: 'OUTDOOR', child: Text('Outdoor')),
                ],
                onChanged: (v) =>
                    setDialogState(() => areaType = v ?? 'INDOOR'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        Toast.error(dialogContext, 'Nama area wajib diisi');
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final response = await _areaApi.updateArea(
                            widget.outcode,
                            a.areaId,
                            nameController.text.trim(),
                            areaType);
                        if (!mounted) return;
                        if (response.statusCode == 200) {
                          Navigator.pop(dialogContext);
                          Toast.success(context, 'Area diperbarui');
                          _load();
                        } else {
                          setDialogState(() => saving = false);
                          Toast.error(dialogContext, 'Gagal memperbarui area');
                        }
                      } catch (_) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          Toast.error(dialogContext, 'Gagal memperbarui area');
                        }
                      }
                    },
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteArea(Area a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Area'),
        content: Text(
            'Hapus area "${a.areaName}"? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await _areaApi.deleteArea(widget.outcode, a.areaId);
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Area dihapus');
        _load();
      } else {
        Toast.error(context, 'Gagal menghapus area');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menghapus area');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final columns = context.columnsFor(minTileWidth: 340, max: 3);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _areaList.isEmpty
                  ? ListView(
                      children: [
                        EmptyState(
                          icon: Icons.map_outlined,
                          title: 'Belum ada area',
                          description:
                              'Area (mis. Lantai 1, Teras Depan) dipakai untuk mengelompokkan meja.',
                          action: ElevatedButton.icon(
                            onPressed: _tambah,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Tambah Area'),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 80,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _areaList.length,
                      itemBuilder: (context, index) {
                        final a = _areaList[index];
                        final indoor = a.areaType == 'INDOOR';
                        return _EntityTile(
                          icon: indoor
                              ? Icons.home_outlined
                              : Icons.deck_outlined,
                          title: a.areaName,
                          subtitle: indoor ? 'Indoor' : 'Outdoor',
                          trailing: _StatusPill(
                            label: a.areaType,
                            positive: indoor,
                            neutral: true,
                          ),
                          onEdit: () => _editArea(a),
                          onDelete: () => _deleteArea(a),
                        );
                      },
                    ),
            ),
      floatingActionButton: _areaList.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _tambah,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Area'),
            ),
    );
  }
}

class _EntityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _EntityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.error),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Hapus',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool positive;
  final bool neutral;

  const _StatusPill({
    required this.label,
    required this.positive,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (neutral) {
      bg = positive ? AppColors.blueLight : AppColors.tealLight;
      fg = positive ? AppColors.blueDark : AppColors.tealDark;
    } else {
      bg = positive ? AppColors.successLight : AppColors.errorLight;
      fg = positive ? AppColors.successDark : AppColors.errorDark;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
