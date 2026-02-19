class LoginResponseModel {
  final String tokenType;
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final int expiresIn;
  final int forceChangePassword;
  final String username;

  LoginResponseModel({
    required this.tokenType,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.expiresIn,
    required this.forceChangePassword,
    required this.username,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      tokenType: json['data']['token_type'] ?? '',
      accessToken: json['data']['access_token'] ?? '',
      refreshToken: json['data']['refresh_token'] ?? '',
      expiresAt: json['data']['expires_at'] ?? 0,
      expiresIn: json['data']['expires_at'] ?? 0,
      forceChangePassword: json['data']['force_change_password'] ?? 0,
      username: json['metadata']['username'] ?? '',
    );
  }

  String get bearerToken => '$tokenType $accessToken';
}
