class UserModel {
  final String email;
  final String username;
  final String? displayPicture;

  UserModel({
    required this.email,
    required this.username,
    this.displayPicture,
  });

  factory UserModel.fromJWT(Map<String, dynamic> jwtPayload) {
    return UserModel(
      email: jwtPayload['email'] ?? '',
      username: jwtPayload['username'] ?? '',
      displayPicture: jwtPayload['display_picture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'display_picture': displayPicture,
    };
  }
}
