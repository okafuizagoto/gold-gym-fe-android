import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';
import '../services/outlet_api.dart';
import '../models/outlet_model.dart';
import '../models/location_model.dart';
import '../utils/bidang_usaha.dart';
import '../utils/outlet_type.dart';
import '../utils/roles.dart';
import '../utils/toast.dart';
import '../widgets/auth_card.dart';
import '../widgets/location_picker.dart';
import '../services/core_api.dart';

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
  final _bidangUsahaLainnyaController = TextEditingController();
  final outletsArrNotifier = ValueNotifier<List<Outlet>>([]);
  String _bidangUsaha = '';

  // Tipe Outlet (2026-10-22): Autocomplete freeSolo -- lihat utils/outlet_type.dart.
  // Di-key ulang (lihat build()) supaya reset ke default setelah addItem/simpan, sama pola
  // dengan LocationPicker di bawah -- RawAutocomplete tidak punya API langsung untuk itu.
  final coreApi = CoreApi();
  String _outletTypeInput = outletTypeDisplayLabel(outletTypeDefault);
  bool _therapyVisible = true;

  bool _isLoading = false;

  ValueNotifier<bool> isActiveOutlet = ValueNotifier(true);
  // Lokasi (2026-10-03, opsional) -- field terbaru dari LocationPicker, dibaca saat addItem/_handleOutlet.
  LocationSelection _location = LocationSelection();
  // Lokasi (2026-10-09): dihitung oleh LocationPicker sendiri -- lengkap berarti SEMUA level yang
  // terbukti punya data (hasil query tidak kosong) sudah terisi. Level tanpa data otomatis tidak
  // ikut dihitung -- opsional, bukan diwajibkan.
  bool _locationComplete = false;

  @override
  void initState() {
    super.initState();
    // STAFF tidak boleh membuat outlet (backend 403) -- jangan tampilkan formnya.
    isStaffRole().then((v) {
      if (mounted && v) {
        final lang = context.read<LanguageProvider>();
        Toast.error(
            context,
            lang.get('Only owners can create outlets.',
                'Hanya pemilik yang boleh membuat outlet.'));
        Navigator.of(context).maybePop();
      }
    });
    // Admin bisa sembunyikan "Jasa Terapi & Spa" dari daftar (menu Akses Admin) --
    // default true (tampil) sampai pengaturan selesai dimuat.
    coreApi.getOutletTypeSettings().then((resp) {
      if (!mounted || resp.statusCode != 200) return;
      final body = jsonDecode(resp.body);
      final visible = body['data']?['therapyVisible'];
      if (visible == false) setState(() => _therapyVisible = false);
    }).catchError((_) {
      // default true -- tidak memblokir form kalau pengaturan gagal dimuat
    });
  }

  @override
  void dispose() {
    _outletAddressController.dispose();
    _outletNameController.dispose();
    _bidangUsahaLainnyaController.dispose();
    outletsArrNotifier.dispose();
    isActiveOutlet.dispose();
    super.dispose();
  }

  String get _bidangUsahaFinal => _bidangUsaha == bidangUsahaLainnya
      ? _bidangUsahaLainnyaController.text.trim()
      : _bidangUsaha;

  String get _outletTypeFinal => resolveOutletTypeValue(_outletTypeInput);

  bool get _formFilled =>
      _outletNameController.text.trim().isNotEmpty &&
      _outletAddressController.text.trim().isNotEmpty;

  Future<void> addItem() async {
    final lang = context.read<LanguageProvider>();
    if (!_formFilled) {
      Toast.error(
          context,
          lang.get('Please fill in the outlet name and address.',
              'Isi nama dan alamat outlet terlebih dahulu.'));
      return;
    }
    if (!_locationComplete) {
      Toast.error(
          context,
          lang.get(
              'Please complete the outlet location (only fields with available data are required).',
              'Lengkapi lokasi outlet (hanya field yang memang ada datanya yang wajib diisi).'));
      return;
    }
    if (_outletTypeFinal.isEmpty) {
      Toast.error(context,
          lang.get('Please specify the outlet type', 'Mohon isi tipe outlet-nya'));
      return;
    }
    {
      final outlet = Outlet(
        outlet_name: _outletNameController.text,
        outlet_address: _outletAddressController.text,
        outlet_status: isActiveOutlet.value,
        bidangUsaha: _bidangUsahaFinal,
        outletType: _outletTypeFinal,
        location: _location.copy(),
      );

      outletsArrNotifier.value = [
        ...outletsArrNotifier.value,
        outlet,
      ];

      _outletNameController.clear();
      _outletAddressController.clear();
      setState(() {
        _location = LocationSelection();
        _bidangUsaha = '';
        _bidangUsahaLainnyaController.clear();
        _outletTypeInput = outletTypeDisplayLabel(outletTypeDefault);
      });
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
        bidangUsaha: _bidangUsahaFinal,
        outletType: _outletTypeFinal,
        location: _location,
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
                  if (item.bidangUsaha.isNotEmpty)
                    "outlet_bidang_usaha": item.bidangUsaha,
                  if (item.outletType.isNotEmpty)
                    "outlet_type": item.outletType,
                  ...?item.location?.toJson(),
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
                  if (item.bidangUsaha.isNotEmpty)
                    "outlet_bidang_usaha": item.bidangUsaha,
                  if (item.outletType.isNotEmpty)
                    "outlet_type": item.outletType,
                  ...?item.location?.toJson(),
                })
            .toList()
      };
    }

    final lang = context.read<LanguageProvider>();
    if (outletsArrNotifier.value.isEmpty && !_formFilled) {
      Toast.error(
          context,
          lang.get('Please fill in the outlet name and address.',
              'Isi nama dan alamat outlet terlebih dahulu.'));
      return;
    }
    if (outletsArrNotifier.value.isEmpty && !_locationComplete) {
      Toast.error(
          context,
          lang.get(
              'Please complete the outlet location (only fields with available data are required).',
              'Lengkapi lokasi outlet (hanya field yang memang ada datanya yang wajib diisi).'));
      return;
    }
    if (outletsArrNotifier.value.isEmpty && _outletTypeFinal.isEmpty) {
      Toast.error(context,
          lang.get('Please specify the outlet type', 'Mohon isi tipe outlet-nya'));
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
        _bidangUsahaLainnyaController.clear();
        _bidangUsaha = '';
        _outletTypeInput = outletTypeDisplayLabel(outletTypeDefault);
        _location = LocationSelection();
        Toast.success(context,
            lang.get('Outlet saved successfully', 'Outlet berhasil disimpan'));
        Navigator.pushReplacementNamed(context, '/outlet');
      } else {
        outletsArrNotifier.value = [];
        Toast.error(context,
            lang.get('Failed to save outlet', 'Gagal menyimpan outlet'));
      }
    } catch (e) {
      if (mounted) {
        Toast.error(context,
            lang.get('Failed to save outlet', 'Gagal menyimpan outlet'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = Provider.of<LanguageProvider>(context);
    return AuthCard(
      title: lang.get('Register Outlet', 'Daftar Outlet'),
      subtitle: lang.get('Create one outlet, or add several at once',
          'Buat satu outlet, atau tambah beberapa sekaligus'),
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
              decoration: InputDecoration(
                labelText: lang.get('Outlet Name', 'Nama Outlet'),
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Autocomplete<String>(
              key: ValueKey('outlet-type-${outletsArrNotifier.value.length}'),
              optionsBuilder: (TextEditingValue textEditingValue) {
                final opts = visibleOutletTypeOptions(_therapyVisible)
                    .map((o) => o.label);
                if (textEditingValue.text.isEmpty) return opts;
                final q = textEditingValue.text.toLowerCase();
                return opts.where((label) => label.toLowerCase().contains(q));
              },
              initialValue: TextEditingValue(text: _outletTypeInput),
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: lang.get('Outlet Type', 'Tipe Outlet'),
                    helperText: lang.get(
                        'Type to search, or pick "Service & Therapy/Spa" to enable the Therapy Booking feature. Not in the list? Just type your own.',
                        'Ketik untuk mencari, atau pilih "Jasa Terapi & Spa" untuk mengaktifkan fitur Booking Terapi. Tidak ada yang cocok? Ketik saja tipe Anda sendiri.'),
                    prefixIcon: const Icon(Icons.storefront_outlined),
                  ),
                  onChanged: (v) => _outletTypeInput = v,
                );
              },
              onSelected: (selection) => setState(() => _outletTypeInput = selection),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              isExpanded: true, // lihat register_screen: tanpa ini meluap di layar 360dp
              initialValue: _bidangUsaha.isEmpty ? null : _bidangUsaha,
              decoration: InputDecoration(
                labelText: lang.get(
                    'Business Type (optional)', 'Bidang Usaha (opsional)'),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: bidangUsahaOptions
                  .map((opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(opt, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _bidangUsaha = v ?? ''),
            ),
            if (_bidangUsaha == bidangUsahaLainnya) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _bidangUsahaLainnyaController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: lang.get(
                      'Specify Business Type', 'Sebutkan Bidang Usaha'),
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
              ),
            ],
            LocationPicker(
              key: ValueKey('loc-picker-${outletsArrNotifier.value.length}'),
              onChanged: (sel) => _location = sel,
              onValidityChange: (complete) =>
                  setState(() => _locationComplete = complete),
            ),
            // Alamat diisi TERAKHIR (2026-10-09) -- di bawah lokasi/kode pos, bukan di atas.
            const SizedBox(height: 14),
            TextField(
              maxLines: 4,
              minLines: 3,
              controller: _outletAddressController,
              decoration: InputDecoration(
                labelText: lang.get('Outlet Address', 'Alamat Outlet') +
                    ' (${lang.get('required', 'wajib')})',
                hintText: lang.get('Write the full outlet address...',
                    'Tulis alamat lengkap outlet...'),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    secondary: const Icon(Icons.toggle_on_outlined),
                    title: Text(lang.get('Outlet Status', 'Status Outlet'),
                        style: textTheme.titleSmall),
                    subtitle: Text(
                      value
                          ? lang.get('Active', 'Aktif')
                          : lang.get('Inactive', 'Non Aktif'),
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
                      lang.get('Outlets to be saved (${items.length})',
                          'Outlet yang akan disimpan (${items.length})'),
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
                label: Text(lang.get('SAVE', 'SIMPAN')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : addItem,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(lang.get('ADD MORE', 'TAMBAH LAGI')),
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
                label: Text(lang.get('BACK', 'KEMBALI')),
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
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            active ? AppColors.successLight : AppColors.chipBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        active ? 'ACTIVE' : 'NON ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              active ? AppColors.successDark : AppColors.muted,
                        ),
                      ),
                    ),
                    if (outlet.outletType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.chipBg,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          outletTypeDisplayLabel(outlet.outletType),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                  ],
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
