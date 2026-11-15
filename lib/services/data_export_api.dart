import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Ekspor data mentah + audit (2026-11-16). Padanan services/dataExport.ts.
class DataExportApi {
  final ApiClient _client = ApiClient();
  static const _base = '/gold-gym/v2/data-export';

  Future<http.Response> overview(String outcode) =>
      _client.get('$_base/overview', queryParams: {'code': outcode});

  Future<http.Response> history({int limit = 50}) =>
      _client.get('$_base/history', queryParams: {'limit': '$limit'});

  /// kind: items | stock | transactions. Respons 200 = bytes CSV (header X-Export-Rows), selain itu JSON {error}.
  Future<http.Response> download(String kind,
      {String outcode = '', String from = '', String to = ''}) {
    final q = <String, String>{};
    if (outcode.isNotEmpty) q['code'] = outcode;
    if (from.isNotEmpty) q['from'] = from;
    if (to.isNotEmpty) q['to'] = to;
    return _client.get('$_base/$kind', queryParams: q);
  }
}
