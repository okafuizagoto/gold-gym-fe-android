import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get baseApiUrl =>
      // dotenv.env['BASE_API_URL'] ?? 'http://10.154.122.108:8085';
      // dotenv.env['BASE_API_URL'] ?? 'http://192.168.1.13:8085';
      // dotenv.env['BASE_API_URL'] ?? 'http://localhost:8085';
      dotenv.env['BASE_API_URL'] ?? 'https://staging-api-v2.okejual.com';

  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'local';

  static bool get isProduction => environment == 'production';
  static bool get isLocal => environment == 'local';
}
