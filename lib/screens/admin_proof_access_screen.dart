import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/sales_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';
import '../widgets/section_card.dart';

class _ProofOutlet {
  final int goldId;
  final String code;
  final String name;
  final String type;
  final String owner;
  final bool enabled;
  _ProofOutlet(
      this.goldId, this.code, this.name, this.type, this.owner, this.enabled);
  String get key => '$goldId|$code';
  factory _ProofOutlet.fromJson(Map<String, dynamic> j) => _ProofOutlet(
        j['outlet_gold_id'] is int
            ? j['outlet_gold_id']
            : int.tryParse('${j['outlet_gold_id']}') ?? 0,
        j['outlet_code'] ?? '',
        j['outlet_name'] ?? '',
        j['outlet_type'] ?? '',
        j['owner_name'] ?? '',
        j['enabled'] == true || j['enabled'] == 1 || j['enabled'] == '1',
      );
}

class _ProofUser {
  final int goldId;
  final String name;
  final String email;
  final String role;
  final String buyerYn;
  final bool enabled;
  _ProofUser(this.goldId, this.name, this.email, this.role, this.buyerYn,
      this.enabled);
  factory _ProofUser.fromJson(Map<String, dynamic> j) => _ProofUser(
        j['gold_id'] is int
            ? j['gold_id']
            : int.tryParse('${j['gold_id']}') ?? 0,
        j['name'] ?? '',
        j['email'] ?? '',
        j['role'] ?? '',
        j['buyer_yn'] ?? '',
        j['enabled'] == true || j['enabled'] == 1 || j['enabled'] == '1',
      );
  // penjual RETAIL/THERAPY berperan sebagai SELLER; label yang lebih jelas
  // dari sekadar role mentah untuk ditampilkan di layar admin.
  String get roleLabel {
    if (role == 'SELLER') return 'Penjual';
    if (role == 'BUYER') return 'Pembeli';
    return role;
  }
}

/// Layar ADMIN: mengatur visibilitas fitur bukti pembayaran transfer
/// (upload di POS/belanja pembeli, tombol "lihat" di Sales History) lewat
/// TIGA gerbang independen — fitur tampil hanya jika SEMUA gerbang aktif:
/// - Global   : nyala/mati untuk seluruh user sekaligus
/// - Per Outlet: nyala/mati per outlet (RETAIL & THERAPY)
/// - Per User  : nyala/mati per akun (penjual maupun pembeli)
class AdminProofAccessScreen extends StatefulWidget {
  const AdminProofAccessScreen({super.key});

  @override
  State<AdminProofAccessScreen> createState() => _AdminProofAccessScreenState();
}

class _AdminProofAccessScreenState extends State<AdminProofAccessScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _salesApi = SalesApi();

  // ---- Global ----
  bool _globalEnabled = true;
  bool _globalLoading = true;
  bool _globalSaving = false;

  // ---- Per Outlet ----
  final _outletSearchController = TextEditingController();
  List<_ProofOutlet> _outlets = [];
  final Map<String, bool> _outletChecked = {};
  bool _outletsLoading = true;
  bool _outletsSaving = false;
  Timer? _outletDebounce;

  // ---- Per User ----
  final _userSearchController = TextEditingController();
  List<_ProofUser> _users = [];
  final Map<int, bool> _userChecked = {};
  bool _usersLoading = true;
  bool _usersSaving = false;
  Timer? _userDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGlobal();
    _loadOutlets('');
    _loadUsers('');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _outletSearchController.dispose();
    _userSearchController.dispose();
    _outletDebounce?.cancel();
    _userDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadGlobal() async {
    setState(() => _globalLoading = true);
    try {
      final resp = await _salesApi.getProofAccessGlobal();
      if (resp.statusCode == 200) {
        _globalEnabled = jsonDecode(resp.body)['enabled'] == true;
      }
    } catch (_) {}
    if (mounted) setState(() => _globalLoading = false);
  }

  Future<void> _toggleGlobal(bool value) async {
    setState(() => _globalSaving = true);
    try {
      final resp = await _salesApi.saveProofAccessGlobal(value);
      if (resp.statusCode == 200) {
        setState(() => _globalEnabled = value);
        if (mounted) {
          Toast.success(
              context,
              value
                  ? 'Fitur diaktifkan untuk semua user'
                  : 'Fitur dinonaktifkan untuk semua user');
        }
      } else if (mounted) {
        Toast.error(context, 'Gagal menyimpan pengaturan global');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menyimpan pengaturan global');
    } finally {
      if (mounted) setState(() => _globalSaving = false);
    }
  }

  Future<void> _loadOutlets(String search) async {
    setState(() => _outletsLoading = true);
    try {
      final resp = await _salesApi.getProofAccessOutlets(search);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _outlets = ((body['data'] ?? []) as List)
            .map((e) => _ProofOutlet.fromJson(e))
            .toList();
        _outletChecked.clear();
        for (final o in _outlets) {
          _outletChecked[o.key] = o.enabled;
        }
      } else if (mounted) {
        Toast.error(context, 'Gagal memuat outlet');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat outlet');
    }
    if (mounted) setState(() => _outletsLoading = false);
  }

  Future<void> _saveOutlets() async {
    if (_outlets.isEmpty) return;
    setState(() => _outletsSaving = true);
    try {
      final items = _outlets
          .map((o) => {
                "gold_id": o.goldId,
                "outcode": o.code,
                "enabled": _outletChecked[o.key] ?? false,
              })
          .toList();
      final resp = await _salesApi.saveProofAccessOutlets(items);
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Akses outlet tersimpan');
        await _loadOutlets(_outletSearchController.text);
      } else if (mounted) {
        Toast.error(context, 'Gagal menyimpan');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menyimpan');
    } finally {
      if (mounted) setState(() => _outletsSaving = false);
    }
  }

  Future<void> _loadUsers(String search) async {
    setState(() => _usersLoading = true);
    try {
      final resp = await _salesApi.getProofAccessUsers(search);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _users = ((body['data'] ?? []) as List)
            .map((e) => _ProofUser.fromJson(e))
            .toList();
        _userChecked.clear();
        for (final u in _users) {
          _userChecked[u.goldId] = u.enabled;
        }
      } else if (mounted) {
        Toast.error(context, 'Gagal memuat user');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat user');
    }
    if (mounted) setState(() => _usersLoading = false);
  }

  Future<void> _saveUsers() async {
    if (_users.isEmpty) return;
    setState(() => _usersSaving = true);
    try {
      final items = _users
          .map((u) => {
                "gold_id": u.goldId,
                "enabled": _userChecked[u.goldId] ?? false,
              })
          .toList();
      final resp = await _salesApi.saveProofAccessUsers(items);
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Akses user tersimpan');
        await _loadUsers(_userSearchController.text);
      } else if (mounted) {
        Toast.error(context, 'Gagal menyimpan');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menyimpan');
    } finally {
      if (mounted) setState(() => _usersSaving = false);
    }
  }

  Widget _buildGlobalTab() {
    final textTheme = Theme.of(context).textTheme;
    if (_globalLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return PageBody(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Pengaturan global',
            icon: Icons.public_rounded,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fitur Bukti Pembayaran'),
              subtitle: Text(_globalEnabled
                  ? 'AKTIF — tampil untuk semua user (kecuali dimatikan per outlet/user)'
                  : 'NONAKTIF — disembunyikan untuk SEMUA user, apa pun pengaturan outlet/user'),
              value: _globalEnabled,
              onChanged: _globalSaving ? null : _toggleGlobal,
              secondary: _globalSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _globalEnabled
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _globalEnabled
                          ? AppColors.successDark
                          : AppColors.disabled,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ketika nonaktif: tombol "Bukti transfer" di Sales History dan '
            'tombol upload foto bukti pembayaran di POS/belanja pembeli akan '
            'disembunyikan. Berlaku untuk penjual RETAIL, penjual THERAPY, dan pembeli.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _saveBar({required bool saving, required VoidCallback onSave}) {
    final pad = context.pagePadding;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 20),
          label: Text(saving ? 'Menyimpan...' : 'SIMPAN'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successDark,
          ),
          onPressed: saving ? null : onSave,
        ),
      ),
    );
  }

  Widget _buildOutletsTab() {
    final textTheme = Theme.of(context).textTheme;
    final pad = context.pagePadding;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchField(
                controller: _outletSearchController,
                hintText: 'Cari nama / alamat outlet...',
                onChanged: (v) {
                  _outletDebounce?.cancel();
                  _outletDebounce = Timer(
                      const Duration(milliseconds: 450), () => _loadOutlets(v));
                },
              ),
              if (!context.isShort) ...[
                const SizedBox(height: 6),
                Text(
                  'Default: fitur AKTIF di semua outlet. Hilangkan centang untuk '
                  'menyembunyikan fitur di outlet tersebut. Simpan hanya berlaku '
                  'untuk outlet yang tampil.',
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _outletsLoading
              ? const Center(child: CircularProgressIndicator())
              : _outlets.isEmpty
                  ? EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Tidak ada outlet',
                      compact: context.isShort,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
                      itemCount: _outlets.length,
                      itemBuilder: (context, i) {
                        final o = _outlets[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            value: _outletChecked[o.key] ?? false,
                            onChanged: (v) => setState(
                                () => _outletChecked[o.key] = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(o.name.toUpperCase(),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${o.owner.isEmpty ? "-" : o.owner} • ${o.type}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (_outlets.isNotEmpty)
          _saveBar(saving: _outletsSaving, onSave: _saveOutlets),
      ],
    );
  }

  Widget _buildUsersTab() {
    final textTheme = Theme.of(context).textTheme;
    final pad = context.pagePadding;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchField(
                controller: _userSearchController,
                hintText: 'Cari nama / email user...',
                onChanged: (v) {
                  _userDebounce?.cancel();
                  _userDebounce = Timer(
                      const Duration(milliseconds: 450), () => _loadUsers(v));
                },
              ),
              if (!context.isShort) ...[
                const SizedBox(height: 6),
                Text(
                  'Default: fitur AKTIF untuk semua akun. Hilangkan centang untuk '
                  'menyembunyikan fitur khusus akun tersebut (penjual atau pembeli).',
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _usersLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'Tidak ada user',
                      compact: context.isShort,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
                      itemCount: _users.length,
                      itemBuilder: (context, i) {
                        final u = _users[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            value: _userChecked[u.goldId] ?? false,
                            onChanged: (v) => setState(
                                () => _userChecked[u.goldId] = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(u.name.isEmpty ? u.email : u.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${u.roleLabel} • ${u.email.isEmpty ? "-" : u.email}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (_users.isNotEmpty)
          _saveBar(saving: _usersSaving, onSave: _saveUsers),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Visibilitas Bukti Pembayaran',
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Global'),
              Tab(text: 'Per Outlet'),
              Tab(text: 'Per User'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: SafeArea(
          top: false,
          child: ContentWidth(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGlobalTab(),
                _buildOutletsTab(),
                _buildUsersTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
