import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_saver/file_saver.dart';
import '../services/sales_api.dart';
import '../utils/toast.dart';

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

  static const _brandGreen = Color(0xFF22C55E);
  static const _whatsappGreen = Color(0xFF25D366);
  static const _ink = Color(0xFF1F2A37);
  static const _muted = Color(0xFF8A94A6);
  static const _bg = Color(0xFFF4F7F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _brandGreen))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 20, color: _ink),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bagikan Struk',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              )),
                          Text('Kirim nota ke pelanggan dengan mudah',
                              style: TextStyle(fontSize: 12.5, color: _muted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _card(
                    padding: const EdgeInsets.all(14),
                    child: _pdfBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              height: 320,
                              child: PdfPreview(
                                build: (format) async => _pdfBytes!,
                                canChangeOrientation: false,
                                canChangePageFormat: false,
                                canDebug: false,
                                allowPrinting: false,
                                allowSharing: false,
                                useActions: false,
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('Nota belum siap',
                                  style: TextStyle(color: _muted)),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Icon(Icons.chat_bubble_rounded,
                          size: 16, color: _whatsappGreen),
                      SizedBox(width: 6),
                      Text('Kirim lewat WhatsApp',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _card(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 14.5),
                          decoration: InputDecoration(
                            hintText: 'Nomor WhatsApp pelanggan',
                            hintStyle: const TextStyle(color: _muted),
                            prefixIcon:
                                const Icon(Icons.phone_rounded, color: _muted),
                            filled: true,
                            fillColor: _bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _shareToWhatsApp,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Bagikan ke WhatsApp',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _whatsappGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _softActionButton(
                          icon: Icons.ios_share_rounded,
                          label: 'Bagikan Lainnya',
                          color: const Color(0xFF3B82F6),
                          onTap: _busy ? null : _shareGeneric,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _softActionButton(
                          icon: Icons.download_rounded,
                          label: 'Unduh Struk',
                          color: _brandGreen,
                          onTap: _busy ? null : _unduhStruk,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _card({required Widget child, required EdgeInsets padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _softActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
