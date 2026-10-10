import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../config/theme.dart';
import '../services/thermal_printer.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Pilih & simpan printer thermal Bluetooth (2026-10-10, QA POS #11) -- sekali dipilih di sini,
/// cetak struk langsung dari Sales History / sesudah transaksi tidak perlu pilih ulang.
class ThermalPrinterScreen extends StatefulWidget {
  const ThermalPrinterScreen({super.key});

  @override
  State<ThermalPrinterScreen> createState() => _ThermalPrinterScreenState();
}

class _ThermalPrinterScreenState extends State<ThermalPrinterScreen> {
  bool _loading = true;
  List<BluetoothInfo> _devices = [];
  String? _savedAddress;
  int _paperWidthMm = 58;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _savedAddress = await ThermalPrinter.savedAddress;
    _paperWidthMm =
        int.tryParse(await Storage.get(AppConstants.thermalPaperWidthKey) ?? '58') ?? 58;
    if (!await ThermalPrinter.isBluetoothReady) {
      setState(() {
        _error = 'Bluetooth belum aktif / izin belum diberikan';
        _loading = false;
      });
      return;
    }
    try {
      _devices = await ThermalPrinter.pairedDevices;
    } catch (_) {
      _error = 'Gagal memuat daftar printer';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _select(BluetoothInfo device) async {
    await ThermalPrinter.saveAddress(device.macAdress);
    setState(() => _savedAddress = device.macAdress);
    if (!mounted) return;
    final connected = await ThermalPrinter.connect(device.macAdress);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(connected
          ? 'Printer "${device.name}" tersimpan & terhubung'
          : 'Printer "${device.name}" tersimpan, tapi gagal konek sekarang'),
    ));
  }

  Future<void> _setPaperWidth(int mm) async {
    setState(() => _paperWidthMm = mm);
    await Storage.set(AppConstants.thermalPaperWidthKey, mm.toString());
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Printer Thermal'),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SectionCard(
                      title: 'Lebar Kertas',
                      icon: Icons.receipt_long_outlined,
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<int>(
                              value: 58,
                              groupValue: _paperWidthMm,
                              title: const Text('58 mm'),
                              onChanged: (v) => _setPaperWidth(v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<int>(
                              value: 80,
                              groupValue: _paperWidthMm,
                              title: const Text('80 mm'),
                              onChanged: (v) => _setPaperWidth(v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Printer Terpasang (Bluetooth)',
                      icon: Icons.bluetooth_rounded,
                      child: _error != null
                          ? EmptyState(
                              icon: Icons.bluetooth_disabled_rounded,
                              title: _error!,
                              description:
                                  'Pastikan Bluetooth aktif & izin diberikan, lalu pasangkan printer dari pengaturan HP terlebih dahulu.',
                            )
                          : _devices.isEmpty
                              ? const EmptyState(
                                  icon: Icons.bluetooth_searching_rounded,
                                  title: 'Belum ada printer terpasang',
                                  description:
                                      'Pasangkan printer thermal lewat pengaturan Bluetooth HP, lalu kembali ke sini.',
                                )
                              : Column(
                                  children: _devices.map((d) {
                                    final selected = d.macAdress == _savedAddress;
                                    return ListTile(
                                      leading: Icon(
                                        Icons.print_rounded,
                                        color: selected
                                            ? AppColors.successDark
                                            : AppColors.muted,
                                      ),
                                      title: Text(d.name),
                                      subtitle: Text(d.macAdress),
                                      trailing: selected
                                          ? const Icon(Icons.check_circle,
                                              color: AppColors.successDark)
                                          : null,
                                      onTap: () => _select(d),
                                    );
                                  }).toList(),
                                ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
