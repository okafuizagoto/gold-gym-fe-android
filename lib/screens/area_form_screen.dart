import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/area_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Form "Tambah Area" (indoor/outdoor) untuk fitur Atur Meja.
class AreaFormScreen extends StatefulWidget {
  const AreaFormScreen({super.key});

  @override
  State<AreaFormScreen> createState() => _AreaFormScreenState();
}

class _AreaFormScreenState extends State<AreaFormScreen> {
  final _areaApi = AreaApi();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _areaType = 'INDOOR';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (outcode.isEmpty) {
      if (mounted) Toast.error(context, 'Outlet belum dipilih');
      return;
    }

    setState(() => _saving = true);
    try {
      final response = await _areaApi.insertArea({
        'outcode': outcode,
        'data': [
          {
            'area_name': _nameController.text.trim(),
            'area_type': _areaType,
          }
        ],
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Area berhasil ditambahkan');
        Navigator.pop(context, true);
      } else {
        final body = jsonDecode(response.body);
        Toast.error(
            context, body['error']?.toString() ?? 'Gagal menambah area');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menambah area');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Tambah Area'),
        body: PageBody(
          maxWidth: 560,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(
                  title: 'Tambah Area',
                  subtitle:
                      'Area dipakai untuk mengelompokkan meja, mis. Lantai 1 atau Teras Depan.',
                  icon: Icons.map_outlined,
                ),
                SectionCard(
                  title: 'Data Area',
                  icon: Icons.edit_location_alt_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nama Area',
                          hintText: 'mis. Lantai 1, Teras Depan',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama area wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _areaType,
                        decoration: const InputDecoration(
                          labelText: 'Tipe Area',
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'INDOOR', child: Text('Indoor')),
                          DropdownMenuItem(
                              value: 'OUTDOOR', child: Text('Outdoor')),
                        ],
                        onChanged: (v) =>
                            setState(() => _areaType = v ?? 'INDOOR'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 20),
                    label: const Text('SIMPAN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
