import 'dart:convert';
import 'storage.dart';

class Permission {
  // Check if user has permission
  static Future<bool> check(String moduleAlias, String permission) async {
    final accessListJson = await Storage.get('access_list');
    if (accessListJson == null) return false;

    try {
      final accessList = jsonDecode(accessListJson) as Map<String, dynamic>;
      final modulePermissions = accessList[moduleAlias];

      if (modulePermissions == null) return false;
      if (modulePermissions is! List) return false;

      return modulePermissions.contains('${moduleAlias}_$permission');
    } catch (e) {
      return false;
    }
  }

  // Returns widget visibility based on permission
  static Future<bool> canDisplay(String moduleAlias, String permission) async {
    return await check(moduleAlias, permission);
  }
}
