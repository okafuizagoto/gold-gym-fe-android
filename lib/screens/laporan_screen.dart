import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';
import '../widgets/segmented_tabs.dart';
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
          appBar: const AppBarCustom(title: 'Laporan Penjualan'),
          drawer: const AppDrawer(),
          body: ContentWidth(
            child: Column(
              children: [
                // pil tab (web: SegmentedTabs) yang menggerakkan TabBarView
                Padding(
                  padding: EdgeInsets.fromLTRB(context.pagePadding,
                      context.pagePadding, context.pagePadding, 4),
                  child: Builder(
                    builder: (context) {
                      final controller = DefaultTabController.of(context);
                      return AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => SegmentedTabs<int>(
                          value: controller.index,
                          onChanged: (i) => controller.animateTo(i),
                          tabs: const [
                            SegmentedTab(
                                value: 0,
                                label: 'Per Hari',
                                icon: Icons.today_rounded),
                            SegmentedTab(
                                value: 1,
                                label: 'Per Minggu',
                                icon: Icons.date_range_rounded),
                            SegmentedTab(
                                value: 2,
                                label: 'Per Bulan',
                                icon: Icons.calendar_month_rounded),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      LaporanHarianView(),
                      LaporanMingguanView(),
                      LaporanBulananView(),
                    ],
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
