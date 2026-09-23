import 'constants.dart';
import 'storage.dart';

/// True kalau akun yang login adalah STAFF (karyawan milik pemilik).
/// Dipakai menyembunyikan aksi yang ditolak backend untuk STAFF, mis.
/// tambah/ubah/hapus outlet (backend: 403 "hanya pemilik yang boleh mengubah outlet").
Future<bool> isStaffRole() async {
  return await Storage.get(AppConstants.userRoleKey) == AppConstants.roleStaff;
}
