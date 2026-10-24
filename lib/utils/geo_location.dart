import 'package:geolocator/geolocator.dart';

/// Gagal membaca lokasi; [message] siap ditampilkan ke pengguna.
class GeoException implements Exception {
  final String message;
  GeoException(this.message);
  @override
  String toString() => message;
}

/// Posisi perangkat untuk absensi bertitik kantor. Izin lokasi hanya diminta saat dipakai
/// (foreground, tanpa lokasi latar belakang); koordinat tidak disimpan di aplikasi maupun server.
/// Padanan utils/geolocation.ts -- bedanya, Android bisa mendeteksi lokasi palsu (isMocked).
/// Mengembalikan body {lat,lng,accuracy_m,mocked} untuk POST clockin/clockout.
Future<Map<String, dynamic>> getCurrentGeo() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw GeoException('GPS mati. Aktifkan lokasi perangkat lalu coba lagi.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied) {
    throw GeoException('Izin lokasi ditolak. Izinkan lokasi untuk absen di kantor.');
  }
  if (perm == LocationPermission.deniedForever) {
    throw GeoException(
        'Izin lokasi diblokir. Buka Pengaturan aplikasi > Izin > Lokasi, lalu izinkan.');
  }
  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy_m': pos.accuracy,
      'mocked': pos.isMocked,
    };
  } on Exception {
    throw GeoException(
        'Lokasi tidak terbaca. Pindah ke tempat terbuka lalu coba lagi.');
  }
}
