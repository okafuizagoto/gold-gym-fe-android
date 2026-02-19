import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../providers/language_provider.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, child) {
        return Scaffold(
          appBar: AppBarCustom(
            title: langProvider.get('About Us', 'Tentang Kami'),
          ),
          drawer: const AppDrawer(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langProvider.get('Contact Information', 'Informasi Kontak'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                _InfoCard(
                  icon: Icons.business,
                  title: langProvider.get('Company', 'Perusahaan'),
                  content: 'Gold Gym Indonesia',
                ),
                const SizedBox(height: 16),

                _InfoCard(
                  icon: Icons.location_on,
                  title: langProvider.get('Address', 'Alamat'),
                  content: 'Jakarta, Indonesia',
                ),
                const SizedBox(height: 16),

                _InfoCard(
                  icon: Icons.phone,
                  title: langProvider.get('Phone', 'Telepon'),
                  content: '+62 xxx xxxx xxxx',
                ),
                const SizedBox(height: 16),

                _InfoCard(
                  icon: Icons.email,
                  title: 'Email',
                  content: 'info@goldgym.co.id',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
