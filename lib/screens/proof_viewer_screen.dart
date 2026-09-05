import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../services/sales_api.dart';
import '../utils/toast.dart';

/// Menampilkan foto bukti pembayaran transfer sebuah nota (dari Sales
/// History). Foto bisa di-download ke galeri HP lewat tombol simpan.
class ProofViewerScreen extends StatefulWidget {
  final String saleTrancnum; // nomor nota (judul)
  final List<Map<String, dynamic>> proofs; // metadata dari type=proofs

  const ProofViewerScreen({
    super.key,
    required this.saleTrancnum,
    required this.proofs,
  });

  @override
  State<ProofViewerScreen> createState() => _ProofViewerScreenState();
}

class _ProofViewerScreenState extends State<ProofViewerScreen> {
  final _salesApi = SalesApi();
  // cache bytes per proof_id supaya tidak fetch ulang saat scroll/simpan
  final Map<int, Uint8List> _photoCache = {};
  // toast "foto tidak tersedia" cuma sekali per proof (FutureBuilder bisa
  // memanggil _loadPhoto berkali-kali saat rebuild/scroll)
  final Set<int> _toastedMissing = {};
  int? _savingProofId;

  Future<Uint8List?> _loadPhoto(int proofId) async {
    if (_photoCache.containsKey(proofId)) return _photoCache[proofId];
    final bytes = await _salesApi.getProofPhoto(proofId);
    if (bytes != null) {
      _photoCache[proofId] = bytes;
    } else if (_toastedMissing.add(proofId)) {
      if (mounted) Toast.error(context, 'Foto tidak tersedia saat ini.');
    }
    return bytes;
  }

  /// Download foto ke galeri HP.
  Future<void> _saveToGallery(int proofId, String filename) async {
    setState(() => _savingProofId = proofId);
    try {
      final bytes = await _loadPhoto(proofId);
      if (bytes == null) {
        if (mounted) Toast.error(context, 'Foto tidak bisa diambil');
        return;
      }
      await Gal.putImageBytes(bytes, name: 'bukti-$filename');
      if (mounted) {
        Toast.success(context, 'Foto tersimpan di galeri');
      }
    } on GalException catch (e) {
      if (mounted) {
        Toast.error(context,
            e.type == GalExceptionType.accessDenied
                ? 'Izin galeri ditolak — aktifkan izin penyimpanan'
                : 'Gagal menyimpan foto');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menyimpan foto');
    } finally {
      if (mounted) setState(() => _savingProofId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bukti Transfer ${widget.saleTrancnum}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.proofs.length,
        itemBuilder: (context, index) {
          final proof = widget.proofs[index];
          final proofId = proof['proof_id'] ?? 0;
          final bytesSize = (proof['proof_bytes'] ?? 0) as num;
          final uploadedBy = '${proof['proof_uploaded_by'] ?? ''}';
          final uploadedAt =
              '${proof['proof_uploaded_at'] ?? ''}'.split('T').join(' ');
          final filename = '${proof['proof_filename'] ?? proofId}';

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<Uint8List?>(
                  future: _loadPhoto(proofId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox(
                        height: 240,
                        child:
                            Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.data == null) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                            child: Text('Foto tidak bisa dimuat')),
                      );
                    }
                    // tap foto untuk lihat penuh (zoom)
                    return GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          insetPadding: const EdgeInsets.all(8),
                          child: InteractiveViewer(
                            child: Image.memory(snapshot.data!),
                          ),
                        ),
                      ),
                      child: Image.memory(
                        snapshot.data!,
                        height: 240,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ukuran: ${(bytesSize / 1024).toStringAsFixed(0)} KB'
                        '${uploadedBy.isNotEmpty ? " • Oleh: $uploadedBy" : ""}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      if (uploadedAt.isNotEmpty)
                        Text(
                          'Diupload: $uploadedAt',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _savingProofId == proofId
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.download),
                          label: const Text('DOWNLOAD KE GALERI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _savingProofId != null
                              ? null
                              : () => _saveToGallery(proofId, filename),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
