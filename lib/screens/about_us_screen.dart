import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/brand_logo.dart';
import '../widgets/page_header.dart';
import '../providers/language_provider.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, child) {
        final textTheme = Theme.of(context).textTheme;
        final columns = context.columnsFor(minTileWidth: 300, max: 2);
        final cards = [
          _InfoCard(
            icon: Icons.business_rounded,
            title: langProvider.get('Company', 'Perusahaan'),
            content: 'Okejual Indonesia',
          ),
          _InfoCard(
            icon: Icons.location_on_rounded,
            title: langProvider.get('Address', 'Alamat'),
            content: 'Jakarta, Indonesia',
          ),
          _InfoCard(
            icon: Icons.phone_rounded,
            title: langProvider.get('Phone', 'Telepon'),
            content: '+62 xxx xxxx xxxx',
          ),
          const _InfoCard(
            icon: Icons.email_rounded,
            title: 'Email',
            content: 'admin@okejual.co.id',
          ),
        ];

        return Scaffold(
          appBar: AppBarCustom(
            title: langProvider.get('About Us', 'Tentang Kami'),
          ),
          drawer: const AppDrawer(),
          body: PageBody(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const BrandLogo(size: 72),
                        const SizedBox(height: 10),
                        Text(
                          AppConstants.appName,
                          style: textTheme.titleLarge
                              ?.copyWith(color: AppColors.blue),
                        ),
                        Text('v${AppConstants.version}',
                            style: textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Text(
                          langProvider.get(
                            'Point of sale for outlets, buyers, and reports in one app',
                            'Sistem kasir untuk outlet, pembeli, dan laporan dalam satu aplikasi',
                          ),
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                PageHeader(
                  title: langProvider.get(
                      'Contact Information', 'Informasi Kontak'),
                  icon: Icons.contact_support_outlined,
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 84,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, i) => cards[i],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 22, color: AppColors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(content,
                      style: textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
