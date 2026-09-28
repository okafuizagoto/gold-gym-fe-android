import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Penyimpanan lokal offline-first: berkas JSON di folder dokumen aplikasi (privat per-aplikasi).
/// Padanan utils/offlineStore.ts (IndexedDB) di web. Dua "koleksi": antrean nota (outbox) dan cache stok per
/// outlet. Tulis diserialkan lewat satu antrean Future supaya dua penulisan bersamaan tidak saling menimpa,
/// dan ditulis ke berkas sementara lalu di-rename (atomik) supaya berkas tidak rusak kalau aplikasi mati
/// di tengah penulisan.
class OfflineStore {
  OfflineStore._();
  static final OfflineStore instance = OfflineStore._();

  Future<void> _lock = Future.value();

  Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/offline_$name.json');
  }

  Future<T> _serial<T>(Future<T> Function() job) {
    final next = _lock.then((_) => job());
    _lock = next.then((_) {}, onError: (_) {});
    return next;
  }

  /// Baca berkas JSON; berkas hilang/rusak -> [fallback] (tidak pernah melempar).
  Future<dynamic> read(String name, dynamic fallback) => _serial(() async {
        try {
          final f = await _file(name);
          if (!await f.exists()) return fallback;
          return jsonDecode(await f.readAsString());
        } catch (e) {
          debugPrint('[OfflineStore] baca $name gagal: $e');
          return fallback;
        }
      });

  Future<void> write(String name, dynamic value) => _serial(() async {
        final f = await _file(name);
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(jsonEncode(value), flush: true);
        await tmp.rename(f.path);
      });
}
