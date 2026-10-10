import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';

/// Cetak struk ESC/POS LANGSUNG ke printer thermal Bluetooth (2026-10-10, QA POS #11) --
/// berbeda dari cetak PDF yang sudah ada (dialog print OS, butuh printer dengan driver
/// Android). Printer thermal 58mm/80mm murah yang umum dipakai warung/toko biasanya TIDAK
/// punya driver -- hanya menerima byte mentah ESC/POS lewat Bluetooth Classic (SPP).
class ThermalPrinter {
  ThermalPrinter._();

  /// MAC address printer yang terakhir dipakai -- diingat supaya kasir tidak perlu pilih
  /// ulang setiap kali cetak.
  static Future<String?> get savedAddress =>
      Storage.get(AppConstants.thermalPrinterAddressKey);

  static Future<void> saveAddress(String address) =>
      Storage.set(AppConstants.thermalPrinterAddressKey, address);

  /// Lebar kertas tersimpan (mm) -- default 58 kalau belum pernah diatur.
  static Future<int> get paperWidthMm async {
    final raw = await Storage.get(AppConstants.thermalPaperWidthKey);
    return int.tryParse(raw ?? '58') ?? 58;
  }

  static Future<bool> get isBluetoothReady async {
    final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!granted) return false;
    return PrintBluetoothThermal.bluetoothEnabled;
  }

  static Future<List<BluetoothInfo>> get pairedDevices =>
      PrintBluetoothThermal.pairedBluetooths;

  static Future<bool> connect(String address) =>
      PrintBluetoothThermal.connect(macPrinterAddress: address);

  static Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  /// Hubungkan ke printer tersimpan (kalau ada) lalu kirim [bytes]. Return pesan error
  /// (null = sukses) supaya caller bisa tampilkan ke kasir.
  static Future<String?> printBytes(List<int> bytes) async {
    if (!await isBluetoothReady) {
      return 'Bluetooth belum aktif / izin belum diberikan';
    }
    final address = await savedAddress;
    if (address == null || address.isEmpty) {
      return 'Belum ada printer thermal tersimpan -- pilih dulu di menu "Printer Thermal"';
    }
    if (!await isConnected) {
      final connected = await connect(address);
      if (!connected) {
        return 'Gagal konek ke printer. Pastikan printer menyala & dalam jangkauan.';
      }
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    return ok ? null : 'Gagal mengirim data ke printer';
  }
}
