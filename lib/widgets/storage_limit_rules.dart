import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/storage_model.dart';
import '../services/storage_api.dart';
import '../services/subscription_api.dart';
import '../utils/toast.dart';
import 'section_card.dart';

const _kindLabel = {
  'ITEM_MAX_KB': 'Foto produk — maks per foto',
  'PROOF_MAX_KB': 'Foto bukti bayar/QRIS — maks per foto',
  'ITEM_QUOTA_KB': 'Foto produk — kuota total per user',
  'PROOF_QUOTA_KB': 'Bukti bayar + QRIS — kuota total per user',
};
const _scopeLabel = {
  'GLOBAL': 'Semua user',
  'PLAN': 'Per paket',
  'USER': 'Per user',
};

bool _isQuota(String kind) =>
    kind == 'ITEM_QUOTA_KB' || kind == 'PROOF_QUOTA_KB';

String _mb(int kb) =>
    '${(kb / 1024).toStringAsFixed(kb % 1024 == 0 ? 0 : 1)} MB';

/// Admin: aturan batas foto (2026-09-25) -- ukuran maks per foto DAN kuota total, untuk foto
/// produk dan foto bukti bayar/QRIS, per user / per paket / semua user. Prioritas: user > paket >
/// semua user. Padanan components/admin/StorageLimitRules.tsx (Next.js).
class StorageLimitRules extends StatefulWidget {
  final VoidCallback? onChanged;
  const StorageLimitRules({super.key, this.onChanged});

  @override
  State<StorageLimitRules> createState() => _StorageLimitRulesState();
}

class _StorageLimitRulesState extends State<StorageLimitRules> {
  final _api = StorageApi();
  final _valueController = TextEditingController();
  final _userIdController = TextEditingController();
  List<LimitRule> _rules = [];
  List<String> _plans = [];
  String _scope = 'GLOBAL';
  String? _plan;
  String _kind = 'ITEM_MAX_KB';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPlans();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rules = await _api.adminListLimitRules();
    if (rules != null && mounted) setState(() => _rules = rules);
  }

  Future<void> _loadPlans() async {
    try {
      final res = await SubscriptionApi().getPlans();
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body)['data'] as List?) ?? [];
        if (mounted) {
          setState(() => _plans = list.map((p) => p['id'].toString()).toList());
        }
      }
    } catch (_) {}
  }

  Future<void> _save({bool remove = false, LimitRule? target}) async {
    final scope = target?.scopeType ?? _scope;
    final kind = target?.kind ?? _kind;
    final key = target != null
        ? target.scopeKey
        : scope == 'GLOBAL'
            ? ''
            : scope == 'PLAN'
                ? (_plan ?? '')
                : _userIdController.text.trim();
    if (scope != 'GLOBAL' && key.isEmpty) {
      Toast.error(
          context, scope == 'PLAN' ? 'Pilih paket' : 'Isi gold ID user');
      return;
    }
    double? limitMb;
    if (!remove) {
      final n =
          double.tryParse(_valueController.text.trim().replaceAll(',', '.'));
      if (n == null || n < 0 || (!_isQuota(kind) && n == 0)) {
        Toast.error(
            context,
            _isQuota(kind)
                ? 'Isi angka MB (0 = tanpa batas)'
                : 'Isi angka MB lebih dari 0');
        return;
      }
      limitMb = n;
    }
    setState(() => _saving = true);
    try {
      final resp = await _api.adminSetLimitRule(scope, key, kind, limitMb);
      if (resp.statusCode == 200) {
        if (mounted) {
          Toast.success(
              context, remove ? 'Aturan dihapus' : 'Aturan tersimpan');
        }
        if (!remove) _valueController.clear();
        await _load();
        widget.onChanged?.call();
      } else {
        String msg = 'Gagal menyimpan aturan';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Aturan batas foto',
      icon: Icons.data_usage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Atur ukuran maks per foto dan kuota total, untuk foto produk dan foto bukti bayar/QRIS. '
            'Prioritas: user > paket > semua user. Bawaan: maks 5 MB per foto; foto produk tidak ikut '
            'kuota total (tetap dipantau); kuota bukti bayar + QRIS 30 MB.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _scope,
            decoration: const InputDecoration(labelText: 'Berlaku untuk'),
            items: _scopeLabel.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() {
              _scope = v ?? 'GLOBAL';
              _plan = null;
            }),
          ),
          if (_scope == 'PLAN') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _plan,
              decoration: const InputDecoration(labelText: 'Paket'),
              items: _plans
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _plan = v),
            ),
          ],
          if (_scope == 'USER') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _userIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Gold ID user'),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Jenis batas'),
            items: _kindLabel.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _kind = v ?? 'ITEM_MAX_KB'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText:
                    _isQuota(_kind) ? 'MB (0 = tanpa batas)' : 'MB per foto'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : () => _save(),
            child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
          const SizedBox(height: 12),
          if (_rules.isEmpty)
            Text('Belum ada aturan — memakai bawaan.',
                style: textTheme.bodySmall)
          else
            ..._rules.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                      '${_scopeLabel[r.scopeType] ?? r.scopeType}${r.scopeKey.isEmpty ? '' : ': ${r.scopeKey}'}'),
                  subtitle: Text(
                      '${_kindLabel[r.kind] ?? r.kind} — ${_isQuota(r.kind) && r.limitKb == 0 ? 'Tanpa batas' : _mb(r.limitKb)}'),
                  trailing: IconButton(
                    tooltip: 'Hapus aturan',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed:
                        _saving ? null : () => _save(remove: true, target: r),
                  ),
                )),
        ],
      ),
    );
  }
}
