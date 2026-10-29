// Data uji untuk long_data_overflow_test.dart: bentuk JSON mengikuti respons backend sebenarnya,
// tetapi semua teks dibuat sangat panjang.
class FakeApi {
  static Object respond(
      String method, String path, Map<String, String> q, String long) {
    // Konteks sesi: satu outlet aktif (cocok dengan outcode OUT01 di sessionPrefs) + panduan sudah dilihat,
    // supaya layar tidak dialihkan ke "Pilih Outlet" atau memulai tur.
    if (path.endsWith('/v2/outlet')) {
      return {
        'data': [
          {
            'outlet_id': '1',
            'outlet_gold_id': 1,
            'outlet_code': 'OUT01',
            'outlet_name': '$long outlet',
            'outlet_type': 'RETAIL',
            'outlet_address': '$long alamat',
            'outlet_status': 'ACTIVE',
            'created_at': '2026-10-01T00:00:00Z',
            'locked': false,
            'outlet_queue_enabled': false,
            'location_label': '$long lokasi',
          }
        ],
        'metadata': {'page': 1, 'limit': 10, 'total_data': 1, 'total_page': 1},
      };
    }
    if (path.endsWith('/v2/onboarding')) {
      return {
        'data': {'seen': true}
      };
    }
    if (path.endsWith('/v2/cust')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'cust_id': i,
              'cust_code': 'CUST-KODE-YANG-PANJANG-$i',
              'cust_name': '$long $i',
              'cust_phone': '0812345678901234567890',
              'cust_outlet_name': '$long outlet',
              'cust_type_id': 1,
              'ct_id': 1,
              'ct_name': '$long tipe',
            }
        ],
      };
    }
    if (path.endsWith('/v2/typecust')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'ct_id': i,
              'ct_name': '$long $i',
              'ct_category': 'Kategori Yang Juga Sangat Panjang Sekali $i',
              'ct_description': '$long deskripsi $long',
              'ct_outcode': 'OUT01',
              'ct_status': 'ACTIVE',
            }
        ],
      };
    }
    if (path.endsWith('/v2/staff')) {
      if (q['type'] == 'menutemplate')
        return {
          'data': {'denied_menu_keys': []}
        };
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'gold_id': 100 + i,
              'gold_email':
                  'staf.dengan.email.yang.sangat.panjang.sekali.$i@domain-panjang.example.com',
              'gold_nama': '$long $i',
              'gold_nomorhp': '0812345678901234567890',
              'gold_owner_id': 1,
            }
        ],
      };
    }
    if (path.endsWith('/v2/meja')) {
      return {
        'data': [
          for (var i = 1; i <= 4; i++)
            {
              'meja_id': i,
              'meja_name': '$long $i',
              'meja_capacity': 4,
              'meja_status': i.isEven ? 'ISI' : 'KOSONG',
              'meja_area_id': 1,
            }
        ],
      };
    }
    if (path.endsWith('/v2/area')) {
      return {
        'data': [
          {'area_id': 1, 'area_name': '$long area', 'area_type': 'INDOOR'},
          {
            'area_id': 2,
            'area_name':
                'Area Outdoor Dengan Nama Yang Juga Sangat Panjang Sekali',
            'area_type': 'OUTDOOR'
          },
        ],
      };
    }
    if (path.endsWith('/v2/expense/summary')) {
      return {
        'data': {
          'total_amount': 987654321.0,
          'count': 3,
          'by_category': [
            {
              'category': 'Kategori Pengeluaran Yang Sangat Panjang Sekali 1',
              'total_amount': 123456789.5,
              'count': 2
            },
            {
              'category':
                  'Kategori Lain Yang Juga Sangat Panjang Sekali Sampai Melebihi Layar',
              'total_amount': 5.0,
              'count': 1
            },
          ],
        },
      };
    }
    if (path.endsWith('/v2/expense')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'expense_id': i,
              'expense_gold_id': 1,
              'expense_outcode': 'OUT01',
              'expense_category':
                  'Kategori Pengeluaran Yang Sangat Panjang Sekali $i',
              'expense_vendor': '$long vendor',
              'expense_amount': 123456789.5,
              'expense_date': '2026-10-29',
              'expense_description': '$long deskripsi $long',
              'expense_is_recurring': i == 1,
              'expense_recurring_period': 'MONTHLY',
              'expense_created_by_gold_id': 1,
              'expense_created_at': '2026-10-29T10:00:00Z',
            }
        ],
      };
    }
    if (path.endsWith('/v2/stock')) {
      return {
        'data': [
          for (var i = 1; i <= 4; i++)
            {
              'stock_id': '$i',
              'stock_gold_id': 1,
              'stock_outcode': 'OUT01',
              'stock_item_id': i,
              'stock_name': '$long barang $i',
              'stock_pack': 'KARTON-BESAR-ISI-48-PCS-SANGAT-PANJANG',
              'stock_qty': 123456,
              'stock_price': 1234567890,
              'stock_brand': 'MEREK YANG NAMANYA SANGAT PANJANG SEKALI',
              'stock_photo': '',
              'stock_created_at': '2026-10-01T00:00:00Z',
              'stock_last_update': '2026-10-29T00:00:00Z',
              'stock_qty_update': '2026-10-29T00:00:00Z',
            }
        ],
        'metadata': {'page': 1, 'limit': 10, 'total_data': 4, 'total_page': 1},
      };
    }
    if (path.endsWith('/v2/pos-queue') || path.endsWith('/v2/pos-queue/mine')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'queue_id': i,
              'queue_number': 100 + i,
              'queue_outcode': 'OUT01',
              'queue_sale_id':
                  'NOTA-DENGAN-NOMOR-YANG-SANGAT-PANJANG-SEKALI-$i',
              'queue_status': 'MENUNGGU',
              'queue_created_at': '2026-10-29T10:00:00Z',
            }
        ],
      };
    }
    if (path.endsWith('/featurerequest/admin')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'request_id': i,
              'request_gold_id': 1,
              'request_role': 'SELLER',
              'request_category': 'Kategori Yang Sangat Panjang Sekali $i',
              'request_type': 'FITUR_BARU',
              'request_menu':
                  'Menu Yang Namanya Sangat Panjang Sekali Sampai Melebihi Layar',
              'request_title': '$long judul',
              'request_description': '$long deskripsi $long deskripsi $long',
              'request_status': 'BARU',
              'request_created_at': '2026-10-29T10:00:00Z',
            }
        ],
      };
    }
    if (path.endsWith('/admin/accounts')) {
      return {
        'total': 3,
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'gold_id': i,
              'nama': '$long $i',
              'email':
                  'email.yang.sangat.panjang.sekali.untuk.uji.overflow.$i@domain-yang-juga-sangat-panjang.example.com',
              'toko': '$long toko',
              'role': i == 1 ? 'ADMIN' : 'SELLER',
              'owner_id': null,
              'active': i != 2,
              'last_login': '2026-10-29T10:00:00Z',
            }
        ],
      };
    }
    return {'data': []};
  }
}
