import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/buyer_cart_provider.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';

/// Bar ringkas outlet tujuan belanja (mode pembeli) untuk layar POS &
/// List Barang: menampilkan outlet terpilih + tombol Ganti (ke layar
/// Pilih Outlet). Pemilihan outlet lengkap (dengan detail & pencarian)
/// ada di layar /pilih-outlet.
class BuyerOutletBar extends StatefulWidget {
  final VoidCallback? onRestored; // dipanggil jika outlet dipulihkan dr storage
  const BuyerOutletBar({super.key, this.onRestored});

  @override
  State<BuyerOutletBar> createState() => _BuyerOutletBarState();
}

class _BuyerOutletBarState extends State<BuyerOutletBar> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// pulihkan pilihan outlet dari storage (persist antar buka aplikasi)
  Future<void> _restore() async {
    final cart = Provider.of<BuyerCartProvider>(context, listen: false);
    if (cart.hasOutlet) return;
    final code = await Storage.get(AppConstants.buyerOutcodeKey) ?? '';
    final name = await Storage.get(AppConstants.buyerOutletNameKey) ?? '';
    if (code.isNotEmpty && mounted) {
      cart.selectOutlet(code, name.isEmpty ? code : name);
      widget.onRestored?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<BuyerCartProvider>(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.store, color: Colors.teal),
        title: Text(
          cart.hasOutlet
              ? 'Outlet: ${cart.outletName.toUpperCase()}'
              : 'Belum pilih outlet',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: Text(cart.hasOutlet ? 'GANTI' : 'PILIH OUTLET'),
          onPressed: () => Navigator.pushNamed(context, '/pilih-outlet'),
        ),
      ),
    );
  }
}
