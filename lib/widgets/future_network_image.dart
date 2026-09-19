import 'package:flutter/material.dart';

/// Gambar yang URL-nya harus ditanya ke backend dulu (async) sebelum bisa
/// dimuat -- padanan AuthImage (Next.js) untuk foto yang sekarang disimpan
/// di Backblaze B2 dan di-serve lewat presigned URL (bukan lagi endpoint
/// backend yang balikin bytes langsung + header auth, lihat doc comment
/// ItemsApi.itemPhotoUrl/SalesApi.proofPhotoUrl/CoreApi.getQrisPhotoUrl).
class FutureNetworkImage extends StatelessWidget {
  /// Fungsi pengambil presigned URL, mis. `() => ItemsApi().itemPhotoUrl(id)`.
  final Future<String?> Function() urlLoader;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext context)? placeholderBuilder;
  final Widget Function(BuildContext context)? errorBuilder;

  const FutureNetworkImage({
    super.key,
    required this.urlLoader,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: urlLoader(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholderBuilder?.call(context) ??
              SizedBox(
                width: width,
                height: height,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
        }
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return errorBuilder?.call(context) ??
              SizedBox(
                width: width,
                height: height,
                child: const Icon(Icons.image_not_supported_outlined),
              );
        }
        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stack) =>
              errorBuilder?.call(context) ??
              SizedBox(
                width: width,
                height: height,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
        );
      },
    );
  }
}
