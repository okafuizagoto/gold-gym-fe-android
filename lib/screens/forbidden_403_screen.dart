import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/private_route.dart';
import '../providers/language_provider.dart';

class Forbidden403Screen extends StatelessWidget {
  const Forbidden403Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(langProvider.get('Access Denied', 'Akses Ditolak')),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.block,
                      size: 100,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '403',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      langProvider.get('Access Denied', 'Akses Ditolak'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      langProvider.get(
                        'You do not have permission to access this page',
                        'Anda tidak memiliki izin untuk mengakses halaman ini',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
                      child: Text(
                        langProvider.get('Go to Home', 'Ke Halaman Utama'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
