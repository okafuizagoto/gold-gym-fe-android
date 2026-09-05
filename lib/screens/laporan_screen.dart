import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';
import 'laporan_harian_screen.dart';
import 'laporan_mingguan_screen.dart';
import 'laporan_bulanan_screen.dart';

/// Layar "Laporan Penjualan" (khusus penjual). Berisi 3 tab: Per Hari,
/// Per Minggu, Per Bulan — masing-masing tab memuat view laporannya sendiri.
class LaporanScreen extends StatelessWidget {
  const LaporanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Laporan Penjualan'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Per Hari', icon: Icon(Icons.today)),
                Tab(text: 'Per Minggu', icon: Icon(Icons.date_range)),
                Tab(text: 'Per Bulan', icon: Icon(Icons.calendar_month)),
              ],
            ),
          ),
          drawer: const AppDrawer(),
          body: const TabBarView(
            children: [
              LaporanHarianView(),
              LaporanMingguanView(),
              LaporanBulananView(),
            ],
          ),
        ),
      ),
    );
  }
}
