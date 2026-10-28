import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Padanan services/customerType.ts -- tipe pelanggan (mis. Reguler/Member/Grosir) per outlet (/v2/typecust).
class CustomerTypeApi extends ApiClient {
  final ApiClient _client = ApiClient();

  Future<http.Response> getAll(String outcode) {
    return _client.get('/gold-gym/v2/typecust', queryParams: {
      'type': 'getallcustomertype',
      'code': outcode,
      'page': '0',
      'length': '0',
    });
  }

  Future<http.Response> insert(Map<String, dynamic> data) {
    return _client.post('/gold-gym/v2/typecust?type=insertcustomertype', {
      'data': [data],
    });
  }

  Future<http.Response> update(Map<String, dynamic> data) {
    return _client
        .put('/gold-gym/v2/typecust?type=updatecustomertype', {'data': data});
  }

  Future<http.Response> remove(int ctId, String outcode) {
    return _client.delete('/gold-gym/v2/typecust', queryParams: {
      'type': 'deletecustomertype',
      'id': '$ctId',
      'code': outcode,
    });
  }
}
