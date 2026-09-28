import 'offline_store.dart';

/// Cache stok/katalog POS per outlet, dipakai saat offline (padanan utils/stockCache.ts di web).
/// Disimpan apa adanya (JSON respons getallstock) + waktu simpan, supaya layar bisa menampilkan
/// "Stok terakhir diperbarui ...". Angka stok di cache HANYA tampilan -- server tetap penentu saat sinkron
/// (stok kurang -> nota ditolak dan ditandai gagal di antrean).
class StockCache {
  StockCache._();
  static const _file = 'stock_cache';

  static Future<void> save(String outcode, Map<String, dynamic> stockResponse) async {
    if (outcode.isEmpty) return;
    final all = Map<String, dynamic>.from(await OfflineStore.instance.read(_file, {}) as Map);
    all[outcode] = {'saved_at': DateTime.now().toIso8601String(), 'data': stockResponse};
    await OfflineStore.instance.write(_file, all);
  }

  /// Respons tersimpan untuk outlet (null bila belum pernah tersimpan) + waktunya.
  static Future<({Map<String, dynamic> data, DateTime savedAt})?> load(String outcode) async {
    final all = await OfflineStore.instance.read(_file, {}) as Map;
    final e = all[outcode];
    if (e is! Map || e['data'] is! Map) return null;
    return (
      data: (e['data'] as Map).cast<String, dynamic>(),
      savedAt: DateTime.tryParse('${e['saved_at']}') ?? DateTime.now(),
    );
  }
}
