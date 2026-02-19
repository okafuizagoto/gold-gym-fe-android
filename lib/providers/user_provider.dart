import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  void setUserFromToken(String token) {
    try {
      // Extract token part (remove "Bearer " prefix if exists)
      final tokenPart = token.startsWith('Bearer ') ? token.substring(7) : token;

      Map<String, dynamic> decodedToken = JwtDecoder.decode(tokenPart);
      _user = UserModel.fromJWT(decodedToken);
      notifyListeners();
    } catch (e) {
      debugPrint('Error decoding JWT: $e');
    }
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  bool get isLoggedIn => _user != null;
}
