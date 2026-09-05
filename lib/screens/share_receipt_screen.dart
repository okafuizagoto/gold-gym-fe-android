import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_saver/file_saver.dart';
import '../config/theme.dart';
import '../services/sales_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/page_header.dart';
import '../widgets/section_card.dart';

class ShareReceiptScreen extends StatefulWidget {
  final String saleId;
  const ShareReceiptScreen({super.key, required this.saleId});

  @override
  State<ShareReceiptScreen> createState() => _ShareReceiptScreenState();
}

class _ShareReceiptScreenState extends State<ShareReceiptScreen> {
  final _salesApi = SalesApi();
  final _phoneController = TextEditingController();
  Uint8List? _pdfBytes;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      final bytes = await _salesApi.getReceiptPdfWithRetry(widget.saleId);
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    }
    return digits;
  }

  Future<void> _shareToWhatsApp() async {
    final phone = _normalizePhone(_phoneController.text);
    if (phone.length < 8) {
      Toast.error(context, 'Isi nomor WhatsApp yang valid');
      return;
    }
    final text = Uri.encodeComponent(
        'Struk pembelian Anda (No. ${widget.saleId}). Nota PDF terlampir di sini, silakan unduh/lampirkan manual dari chat ini.');
    final uri = Uri.parse('https://wa.me/$phone?text=$text');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal membuka WhatsApp');
    }
  }

  Future<void> _shareGeneric() async {
    if (_pdfBytes == null) return;
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nota-${widget.saleId}.pdf');
      await file.writeAsBytes(_pdfBytes!);
      await Share.shareXFiles([XFile(file.path)], text: 'Struk pembelian');
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal membagikan struk');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unduhStruk() async {
    if (_pdfBytes == null) return;
    setState(() => _busy = true);
    try {
      await FileSaver.instance.saveFile(
        name: 'nota-${widget.saleId}',
        bytes: _pdfBytes!,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (mounted) Toast.success(context, 'Struk berhasil diunduh');
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal mengunduh struk');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _whatsappGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // pratinjau PDF lebih pendek di HP landscape supaya form tetap terjangkau
    final previewHeight = context.isShort ? 200.0 : 320.0;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : PageBody(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      title: 'Bagikan Struk',
                      subtitle: 'Kirim nota ke pelanggan dengan mudah',
                      onBack: () => Navigator.pop(context),
                    ),
                    SectionCard(
                      dense: true,
                      padding: const EdgeInsets.all(12),
                      child: _pdfBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: SizedBox(
                                height: previewHeight,
                                child: PdfPreview(
                                  build: (format) async => _pdfBytes!,
                                  canChangeOrientation: false,
                                  canChangePageFormat: false,
                                  canDebug: false,
                                  allowPrinting: false,
                                  allowSharing: false,
                                  useActions: false,
                                  scrollViewDecoration: const BoxDecoration(
                                      color: AppColors.background),
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text('Nota belum siap',
                                    style: textTheme.bodyMedium
                                        ?.copyWith(color: AppColors.muted)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      icon: Icons.chat_bubble_rounded,
                      title: 'Kirim lewat WhatsApp',
                      description:
                          'Nomor pelanggan, lalu lampirkan PDF dari chat',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'Nomor WhatsApp pelanggan',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _shareToWhatsApp,
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text('Bagikan ke WhatsApp'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _whatsappGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _softActionButton(
                            icon: Icons.ios_share_rounded,
                            label: 'Bagikan Lainnya',
                            color: AppColors.blue,
                            onTap: _busy ? null : _shareGeneric,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _softActionButton(
                            icon: Icons.download_rounded,
                            label: 'Unduh Struk',
                            color: AppColors.successDark,
                            onTap: _busy ? null : _unduhStruk,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _softActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
