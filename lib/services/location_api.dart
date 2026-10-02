import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Endpoint lokasi: READ-ONLY, tidak butuh token (lihat backend internal/delivery/http/location).
class LocationApi extends ApiClient {
  Future<http.Response> getCountries({String search = ''}) {
    final client = ApiClient();
    return client.get('/gold-gym/v2/location/countries', queryParams: {
      if (search.isNotEmpty) 'search': search,
    });
  }

  /// parentId null = level teratas negara itu (provinsi/state).
  Future<http.Response> getDivisions({required int countryId, int? parentId, int level = 0}) {
    final client = ApiClient();
    return client.get('/gold-gym/v2/location/divisions', queryParams: {
      'country_id': '$countryId',
      if (parentId != null) 'parent_id': '$parentId',
      if (level > 0) 'level': '$level',
    });
  }

  Future<http.Response> searchDivisions({required int countryId, required String q, int level = 0}) {
    final client = ApiClient();
    return client.get('/gold-gym/v2/location/divisions/search', queryParams: {
      'country_id': '$countryId',
      'q': q,
      if (level > 0) 'level': '$level',
    });
  }

  Future<http.Response> getBreadcrumb(int divisionId) {
    final client = ApiClient();
    return client.get('/gold-gym/v2/location/divisions/$divisionId/breadcrumb');
  }
}
