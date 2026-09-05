import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/area_model.dart';
import '../models/meja_model.dart';
import '../models/outlet_model.dart';
import '../services/area_api.dart';
import '../services/meja_api.dart';
import '../services/outlet_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';
import '../config/routes.dart';

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
    return PrivateRoute(
      sellerOnly: true,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: const AppBarCustom(title: 'Meja & Area'),
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
                        onChanged: (v) => setState(() => _selectedOutcode = v),
                      ),
                    ),
                    const TabBar(
                      labelColor: Colors.black,
                      tabs: [
                        Tab(text: 'Meja', icon: Icon(Icons.table_bar)),
                        Tab(text: 'Area', icon: Icon(Icons.map_outlined)),
                      ],
                    ),
                    Expanded(
                      child: _selectedOutcode == null
                          ? const Center(child: Text('Belum ada outlet'))
                          : TabBarView(
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
  bool _loading = true;
  List<Meja> _mejaList = [];

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _mejaList.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('Belum ada meja.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _mejaList.length,
                      itemBuilder: (context, index) {
                        final m = _mejaList[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.table_bar),
                            title: Text(m.mejaName),
                            subtitle: Text('Kapasitas ${m.mejaCapacity} orang'),
                            trailing: Chip(
                              label: Text(m.isKosong ? 'Kosong' : 'Isi'),
                              backgroundColor:
                                  m.isKosong ? Colors.green[100] : Colors.red[100],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result =
              await Navigator.pushNamed(context, AppRoutes.tambahMeja);
          if (result == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Meja'),
      ),
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
        final list = (body['data'] as List? ?? [])
            .map((e) => Area.fromJson(e))
            .toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _areaList.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('Belum ada area.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _areaList.length,
                      itemBuilder: (context, index) {
                        final a = _areaList[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(a.areaType == 'INDOOR'
                                ? Icons.home_outlined
                                : Icons.deck_outlined),
                            title: Text(a.areaName),
                            subtitle: Text(a.areaType),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result =
              await Navigator.pushNamed(context, AppRoutes.tambahArea);
          if (result == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Area'),
      ),
    );
  }
}
