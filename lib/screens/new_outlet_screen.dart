import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/outlet_api.dart';
import '../models/outlet_model.dart';
import '../utils/toast.dart';
import '../widgets/auth_card.dart';

class NewOutletScreen extends StatefulWidget {
  const NewOutletScreen({super.key});

  @override
  State<NewOutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<NewOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final outletsApi = OutletsApi();
  final _outletAddressController = TextEditingController();
  final _outletNameController = TextEditingController();
  final outletsArrNotifier = ValueNotifier<List<Outlet>>([]);

  bool _isLoading = false;

  ValueNotifier<bool> isActiveOutlet = ValueNotifier(true);

  @override
  void dispose() {
    _outletAddressController.dispose();
    _outletNameController.dispose();
    outletsArrNotifier.dispose();
    isActiveOutlet.dispose();
    super.dispose();
  }

  bool get _formFilled =>
      _outletNameController.text.trim().isNotEmpty &&
      _outletAddressController.text.trim().isNotEmpty;

  Future<void> addItem() async {
    if (_formFilled) {
      final outlet = Outlet(
        outlet_name: _outletNameController.text,
        outlet_address: _outletAddressController.text,
        outlet_status: isActiveOutlet.value,
      );

      outletsArrNotifier.value = [
        ...outletsArrNotifier.value,
        outlet,
      ];

      _outletNameController.clear();
      _outletAddressController.clear();
      setState(() {});
    } else {
      Toast.error(context, 'Isi nama dan alamat outlet terlebih dahulu.');
    }
  }

  void deleteItem(int index) {
    final updatedList = List<Outlet>.from(outletsArrNotifier.value);
    updatedList.removeAt(index);

    outletsArrNotifier.value = updatedList;
  }

  Future<void> _handleOutlet() async {
    List<Outlet> arrayOneOutlet = [];
    Map<String, dynamic> bodyData;

    if (outletsArrNotifier.value.isEmpty) {
      final outlet = Outlet(
        outlet_name: _outletNameController.text,
        outlet_address: _outletAddressController.text,
        outlet_status: isActiveOutlet.value,
      );
      arrayOneOutlet = [
        ...arrayOneOutlet,
        outlet,
      ];
      bodyData = {
        "data": arrayOneOutlet
            .map((item) => {
                  "outlet_name": item.outlet_name,
                  "outlet_address": item.outlet_address,
                  "outlet_status": item.outlet_status ? "ACTIVE" : "NON ACTIVE",
                })
            .toList()
      };
    } else {
      bodyData = {
        "data": outletsArrNotifier.value
            .map((item) => {
                  "outlet_name": item.outlet_name,
                  "outlet_address": item.outlet_address,
                  "outlet_status": item.outlet_status ? "ACTIVE" : "NON ACTIVE",
                })
            .toList()
      };
    }

    if (outletsArrNotifier.value.isEmpty && !_formFilled) {
      Toast.error(context, 'Isi nama dan alamat outlet terlebih dahulu.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await outletsApi.insertOutlet(bodyData);
      if (!mounted) return;
      if (response.statusCode == 200) {
        arrayOneOutlet = [];
        outletsArrNotifier.value = [];
        _outletNameController.clear();
        _outletAddressController.clear();
        Toast.success(context, 'Outlet berhasil disimpan');
        Navigator.pushReplacementNamed(context, '/outlet');
      } else {
        outletsArrNotifier.value = [];
        Toast.error(context, 'Gagal menyimpan outlet');
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal menyimpan outlet');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AuthCard(
      title: 'Daftar Outlet',
      subtitle: 'Buat satu outlet, atau tambah beberapa sekaligus',
      maxWidth: 520,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _outletNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Outlet',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              maxLines: 4,
              minLines: 3,
              controller: _outletAddressController,
              decoration: const InputDecoration(
                labelText: 'Alamat Outlet',
                hintText: 'Tulis alamat lengkap outlet...',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Status aktif -- label & switch fleksibel, tidak lagi memakai
            // jarak tetap yang meluap di HP kecil
            ValueListenableBuilder<bool>(
              valueListenable: isActiveOutlet,
              builder: (context, value, child) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SwitchListTile(
                    value: value,
                    onChanged: (v) => isActiveOutlet.value = v,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    secondary: const Icon(Icons.toggle_on_outlined),
                    title: Text('Status Outlet', style: textTheme.titleSmall),
                    subtitle: Text(
                      value ? 'Aktif' : 'Non Aktif',
                      style: textTheme.bodySmall?.copyWith(
                        color: value ? AppColors.successDark : AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),

            ValueListenableBuilder<List<Outlet>>(
              valueListenable: outletsArrNotifier,
              builder: (context, items, child) {
                if (items.isEmpty) {
                  return const SizedBox(); // belum ada data
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Outlet yang akan disimpan (${items.length})',
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PendingOutletTile(
                          index: i + 1,
                          outlet: items[i],
                          onDelete: () => deleteItem(i),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleOutlet,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: const Text('SIMPAN'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : addItem,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('TAMBAH LAGI'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/outlet');
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: const Text('KEMBALI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingOutletTile extends StatelessWidget {
  final int index;
  final Outlet outlet;
  final VoidCallback onDelete;

  const _PendingOutletTile({
    required this.index,
    required this.outlet,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = outlet.outlet_status;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.blueLight,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.blue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outlet.outlet_name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                Text(
                  outlet.outlet_address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: active ? AppColors.successLight : AppColors.chipBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    active ? 'ACTIVE' : 'NON ACTIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.successDark : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
