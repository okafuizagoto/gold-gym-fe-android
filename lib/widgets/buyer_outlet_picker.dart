import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.storefront_rounded,
                size: 20, color: AppColors.tealDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cart.hasOutlet ? 'Outlet tujuan' : 'Belum pilih outlet',
                  style: textTheme.bodySmall,
                ),
                Text(
                  cart.hasOutlet ? cart.outletName.toUpperCase() : '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(cart.hasOutlet ? 'Ganti' : 'Pilih'),
            onPressed: () => Navigator.pushNamed(context, '/pilih-outlet'),
          ),
        ],
      ),
    );
  }
}
