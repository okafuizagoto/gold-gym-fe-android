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
    if (path.contains('/stock-transfer/permissions/')) {
      return {
        'data': {
          'staff_gold_id': 101,
          'send_level': 'PERSETUJUAN',
          'receive_level': 'LANGSUNG'
        }
      };
    }
    if (path.endsWith('/v2/staff') && q['type'] == 'office') {
      return {
        'data': {
          'configured': true,
          'name': '$long kantor $long',
          'lat': -6.2,
          'lng': 106.8,
          'radius_m': 100
        }
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
    if (path.endsWith('/cashier-shift/current')) {
      return {
        'data': {
          'shift_id': 1,
          'shift_status': 'OPEN',
          'shift_opening_cash': 100000,
          'shift_opened_by': '$long kasir',
          'has_prev': true,
          'handoff_by': '$long',
          'handoff_diff': 5000,
          'handoff_gap_net': 5000,
          'handoff_reason': '$long alasan selisih $long',
          'verify_status': 'PENDING',
          'verify_by': '$long',
          'verify_note': '$long catatan',
        }
      };
    }
    if (path.endsWith('/cashier-shift/ledger')) {
      return {
        'data': {
          'date': '2026-10-29',
          'opening': 100000,
          'cash_sales': 123456789,
          'cash_in': 50000,
          'cash_out': 20000,
          'cash_refunds': 10000,
          'non_cash': 999999,
          'sales_count': 12,
          'expected': 123576789,
          'counted': 123456789,
          'end_balance': 123456789,
          'movements': [
            for (var i = 1; i <= 3; i++)
              {
                'id': i,
                'kind': i == 1 ? 'TAMBAH' : 'TARIK',
                'amount': 12345678,
                'at': '2026-10-29T10:00:00Z',
                'by': '$long petugas',
                'by_role': 'STAFF',
                'description': '$long keterangan $long',
                'ref': 'REF-NOMOR-REFERENSI-YANG-SANGAT-PANJANG-$i',
                'balance': 123456789,
              }
          ],
          'shifts': [
            {
              'shift_id': 1,
              'verify_status': 'PENDING',
              'verify_note': '$long',
              'verify_by': '$long',
              'handoff_diff': 5000,
              'handoff_gap_net': 5000,
              'handoff_prev_counted': 100000,
              'handoff_expected': 105000,
              'shift_opening_cash': 100000,
              'handoff_reason': '$long alasan $long',
              'handoff_by': '$long',
            }
          ],
        }
      };
    }
    if (path.endsWith('/v2/cashier-shift')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'shift_id': i,
              'shift_status': 'CLOSED',
              'shift_opening_cash': 100000,
              'shift_opened_by': '$long kasir $i',
              'shift_difference': -5000,
              'verify_status': 'PENDING',
              'verify_note': '$long',
              'handoff_by': '$long',
              'handoff_reason': '$long alasan $long',
              'handoff_diff': 5000,
            }
        ]
      };
    }
    if (path.endsWith('/usage-stats/online-now')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'gold_id': 1000 + i,
              'nama': '$long $i',
              'email':
                  'email.yang.sangat.panjang.sekali.untuk.uji.overflow.$i@domain-yang-juga-sangat-panjang.example.com',
              'role': 'SELLER',
            }
        ],
      };
    }
    if (path.endsWith('/v2/sales') && q['type'] == 'posoutlets') {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'outlet_gold_id': i,
              'outlet_code': 'OUT0$i',
              'outlet_name': '$long outlet $i',
              'outlet_address': '$long alamat',
              'owner_name': '$long pemilik',
              'optional': i != 2,
            }
        ],
      };
    }
    if (path.endsWith('/v2/sales') &&
        q['type'] == 'salesreport' &&
        q['mode'] == 'week') {
      return {
        'data': {
          'label': 'Minggu Yang Labelnya Sangat Panjang Sekali $long',
          'range_start': '2026-10-26',
          'range_end': '2026-11-01',
          'grand_total': 123456789.0,
          'days': [
            for (var i = 0; i < 7; i++)
              {'date': '2026-10-${26 + i}', 'total': 12345678.0, 'count': 123}
          ],
        }
      };
    }
    if (path.endsWith('/v2/sales') &&
        q['type'] == 'salesreport' &&
        q['mode'] == 'month') {
      return {
        'data': {
          'month': '2026-10',
          'label': 'Oktober 2026 $long',
          'grand_total': 987654321.0,
          'weeks': [
            for (var i = 1; i <= 5; i++)
              {
                'week_no': i,
                'label': 'Minggu ke-$i $long',
                'range_start': '2026-10-0$i',
                'range_end': '2026-10-1$i',
                'total': 123456789.0,
                'count': 4567,
              }
          ],
        }
      };
    }
    if (path.endsWith('/v2/sales') && q['type'] == 'dashboardtrend') {
      return {
        'data': {
          'range_start': '2026-10-01',
          'range_end': '2026-10-29',
          'days': [
            for (var i = 1; i <= 10; i++)
              {'date': '2026-10-0$i', 'total': 1234567.0 * i, 'count': i}
          ],
          'total_revenue': 987654321.0,
          'total_transactions': 123456,
          'average_order_value': 12345678.0,
          'prev_period_revenue': 87654321.0,
          'revenue_change_percent': 123.4,
          'top_items': [
            for (var i = 1; i <= 5; i++)
              {
                'item_name': '$long barang $i',
                'qty': 12345,
                'revenue': 98765432.0
              }
          ],
        }
      };
    }
    if (path.endsWith('/v2/order')) {
      final type = q['type'];
      if (type == 'outlets' || type == 'alloutlets') {
        return {
          'data': [
            for (var i = 1; i <= 3; i++)
              {
                'outlet_gold_id': i,
                'outlet_code': 'OUT0$i',
                'outlet_name': '$long outlet $i',
                'outlet_type': 'RETAIL',
                'outlet_address': '$long alamat',
                'owner_name': '$long pemilik',
                'visible': i != 2,
              }
          ],
        };
      }
      if (type == 'buyerorders' || type == 'sellerorders') {
        return {
          'data': [
            for (var i = 1; i <= 3; i++)
              {
                'order_id': 'ORDER-DENGAN-NOMOR-YANG-SANGAT-PANJANG-SEKALI-$i',
                'order_buyer_id': i,
                'order_buyer_name': '$long pembeli',
                'order_gold_id': 1,
                'order_outcode': 'OUT01',
                'order_outlet_name': '$long outlet',
                'order_total': 123456789.0,
                'order_pay_type': 'TRANSFER',
                'order_paid_yn': 'N',
                'order_status': 'WAITING',
                'order_created_at': '2026-10-29T10:00:00Z',
              }
          ],
        };
      }
    }
    if (path.endsWith('/v2/sales') && q['type'] == 'salesreport') {
      return {
        'data': {
          'date': '2026-10-29',
          'count': 3,
          'grand_total': 123456789.0,
          'refund_total': 1000.0,
          'exchange_total': 0,
          'net_total': 123455789.0,
          'items': [
            for (var i = 1; i <= 3; i++)
              {
                'sale_id': 'SALE-$i',
                'trancnum': 'INV-NOMOR-NOTA-YANG-SANGAT-PANJANG-SEKALI-$i',
                'customer': '$long customer',
                'salesperson': '$long kasir',
                'trans_time': '10:00:00',
                'item_name': '$long barang',
                'qty': 12,
                'price': 123456.0,
                'subtotal': 1481472.0,
                'remaining': 5,
              }
          ],
        }
      };
    }
    if (path.endsWith('/v2/sales') && q['type'] == 'getallsales') {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'sale_id': 'SALE-$i',
              'sale_outcode': 'OUT01',
              'sale_trancnum': 'INV-NOMOR-NOTA-YANG-SANGAT-PANJANG-SEKALI-$i',
              'sale_transtime': '10:00:00',
              'sale_transdate': '2026-10-29T10:00:00+07:00',
              'sale_transtotal': 123456789.0,
              'sale_transpayment': 123456789.0,
              'sale_transchange': 0,
              'sale_salesperson': '$long kasir',
              'sale_salescustomer': '$long customer',
              'sale_paymentyn': 'Y',
              'sale_pay_type': 'TRANSFER BANK',
              'sale_meja_names':
                  'Meja 1, Meja Dengan Nama Yang Panjang Sekali, Meja 3, Meja 4',
              'sale_void_yn': i == 3 ? 'Y' : 'N',
              'sale_void_reason': '$long alasan void',
              'sale_voided_by': '$long',
            }
        ],
        'metadata': {'page': 1, 'limit': 10, 'total_data': 3, 'total_page': 1},
      };
    }
    if (path.endsWith('/v2/discount') && q['type'] == 'getdiscounts') {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'discount_id': i,
              'discount_gold_id': 1,
              'discount_outcode': 'OUT01',
              'discount_scope': 'ITEM',
              'discount_item_id': i,
              'discount_item_name': '$long barang $i',
              'discount_type': 'PERCENT',
              'discount_value': 12.5,
              'discount_status': 'ACTIVE',
              'discount_created_by': '$long',
              'discount_created_at': '2026-10-29T10:00:00Z',
            }
        ],
        'metadata': {'page': 1, 'limit': 10, 'total_data': 3, 'total_page': 1},
      };
    }
    if (path.endsWith('/v2/refund') && q['type'] == 'list') {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'refund_id': 'R-$i',
              'refund_number': 'RF-NOMOR-REFUND-YANG-SANGAT-PANJANG-SEKALI-$i',
              'refund_sale_id': 'SALE-$i',
              'refund_sale_number':
                  'INV-NOMOR-NOTA-YANG-SANGAT-PANJANG-SEKALI-$i',
              'refund_outcode': 'OUT01',
              'refund_date': '2026-10-29',
              'refund_time': '10:00:00',
              'refund_by': '$long petugas',
              'refund_reason': '$long alasan refund $long',
              'refund_method': 'CASH',
              'refund_mode': i == 2 ? 'EXCHANGE' : 'MONEY_BACK',
              'refund_total': 123456789.0,
              'refund_exchange_total': i == 2 ? 100000.0 : 0,
              'refund_net': -123456789.0,
              'refund_net_method': 'CASH',
              'refund_cash_delta': -123456789.0,
            }
        ],
        'metadata': {'page': 1, 'limit': 20, 'total_data': 3, 'total_page': 1},
      };
    }
    if (path.endsWith('/v2/stock-transfer')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'id': i,
              'number': 'TRF-NOMOR-TRANSFER-YANG-SANGAT-PANJANG-SEKALI-$i',
              'from_outcode': 'OUT01',
              'from_name': '$long asal',
              'to_outcode': 'OUT02',
              'to_name': '$long tujuan',
              'status': 'DIKIRIM',
              'note': '$long catatan $long',
              'created_by_name': '$long',
              'created_at': '2026-10-29T10:00:00Z',
              'sent_by_name': '$long',
              'sent_at': '2026-10-29T10:00:00Z',
              'items': [
                {
                  'item_id': 1,
                  'name': '$long barang',
                  'pack': 'KARTON-BESAR-PANJANG',
                  'qty': 12
                }
              ],
            }
        ],
      };
    }
    if (path.endsWith('/v2/items')) {
      return {
        'data': [
          for (var i = 1; i <= 4; i++)
            {
              'item_id': i,
              'item_gold_id': 1,
              'item_code': 'KODE-BARANG-YANG-SANGAT-PANJANG-SEKALI-$i',
              'item_name': '$long barang $i',
              'item_type': 'TIPE-BARANG-PANJANG',
              'item_pack': 'KARTON-BESAR-ISI-48-PCS-SANGAT-PANJANG',
              'item_price': 1234567890.0,
              'item_brand': 'MEREK YANG NAMANYA SANGAT PANJANG SEKALI',
              'item_description': '$long deskripsi $long',
              'item_status': 'ACTIVE',
              'item_photo': '',
              'item_barcode': '8999999999999999999',
              'item_created_at': '2026-10-01T00:00:00Z',
            }
        ],
        'metadata': {'page': 1, 'limit': 10, 'total_data': 4, 'total_page': 1},
      };
    }
    if (path.endsWith('/cashier-shift/cash-moves')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'id': i,
              'kind': 'IN',
              'amount': 123456789.0,
              'reason': '$long alasan',
              'by': '$long kasir',
              'by_role': 'STAFF',
              'at': '2026-10-29T10:00:00Z',
            }
        ],
      };
    }
    if (path.endsWith('/v2/storage')) {
      return {
        'data': {
          'used_kb': 123456,
          'quota_kb': 204800,
          'item_used_kb': 23456,
          'item_quota_kb': 102400,
          'item_max_kb': 2048,
          'proof_max_kb': 1024,
          'proof_enabled': true,
          'entries': [
            for (var i = 1; i <= 3; i++)
              {
                'source_type': const [
                  'ITEM_PHOTO',
                  'PAYMENT_PROOF',
                  'QRIS_PHOTO'
                ][i - 1],
                'source_id': i,
                'label': '$long barang $i',
                'context_text': '$long konteks',
                'size_kb': 123456,
                'uploaded_at': '2026-10-29T10:00:00Z',
              }
          ],
        }
      };
    }
    if (path.endsWith('/featurerequest/mine')) {
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
    if (path.endsWith('/userdata/plans')) {
      return {
        'ui': {'show_marketplace': true, 'show_booking': true},
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'id': 'plan$i',
              'name': 'Paket Yang Namanya Sangat Panjang Sekali $i',
              'price_monthly': 1234567890,
              'price_yearly': 1234567890,
              'max_outlets': 12345,
              'max_users': 12345,
              'features': [
                for (var f = 1; f <= 4; f++)
                  'Fitur dengan keterangan yang sangat panjang sekali sampai melebihi lebar layar HP $f'
              ],
              'original_price_monthly': 1234567890,
              'original_price_yearly': 1234567890,
              'discount_percent': 50.0,
            }
        ],
      };
    }
    if (path.endsWith('/v2/payment')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'payment_order_id': 'ORDER-DENGAN-NOMOR-YANG-SANGAT-PANJANG-$i',
              'outlet_name': '$long outlet',
              'user_name': '$long pengguna',
              'user_email':
                  'email.yang.sangat.panjang.sekali.untuk.uji.overflow.$i@domain-yang-juga-sangat-panjang.example.com',
              'payment_amount': 1234567890.0,
              'payment_method': 'QRIS',
              'payment_status': 'PAID',
              'payment_sale_id': null,
              'created_at': '2026-10-29T10:00:00Z',
            }
        ],
        'metadata': {'page': 1, 'limit': 10, 'total_data': 3, 'total_page': 1},
      };
    }
    if (path.endsWith('/v2/backup')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'backup_id': i,
              'environment': 'production-lingkungan-panjang',
              'service_name': 'layanan-dengan-nama-yang-sangat-panjang-sekali-$i',
              'size_bytes': 123456789012,
              'status': 'FAILED',
              'error_message': '$long galat $long',
              'created_at': '2026-10-29T10:00:00Z',
            }
        ],
      };
    }
    if (path.endsWith('/v2/order') && q['type'] == 'catalog') {
      return {
        'data': [
          for (var i = 1; i <= 4; i++)
            {
              'stock_id': '$i',
              'stock_name': '$long barang $i',
              'stock_pack': 'KARTON-BESAR-ISI-48-PCS-SANGAT-PANJANG',
              'stock_qty': 123456,
              'price': 1234567890,
              'brand': 'MEREK YANG NAMANYA SANGAT PANJANG SEKALI',
            }
        ],
      };
    }
    if (path.endsWith('/v2/booking') && q['type'] == 'slots') {
      return {
        'data': [
          for (var i = 0; i < 4; i++)
            {
              'start': '1$i:00',
              'end': '1$i:30',
              'capacity': 3,
              'used': 2,
              'available': 1,
              'has_unpaid': true,
              'full': false,
              'past': false,
              'bookings': [
                {
                  'booking_id': 'BOOK-$i',
                  'cust_name': '$long pelanggan',
                  'registered_yn': 'Y',
                  'status': 'UNPAID',
                  'duration': 60,
                  'start': '1$i:00',
                  'therapy_type': 'DRAGON',
                  'price': 1234567890,
                }
              ],
            }
        ],
      };
    }
    if (path.endsWith('/account/profile')) {
      return {
        'nama': long,
        'email':
            'email.yang.sangat.panjang.sekali.untuk.uji.overflow@domain-yang-juga-sangat-panjang.example.com',
        'nomor_hp': '+6281234567890123456789',
      };
    }
    if (path.endsWith('/storage/admin/users')) {
      return {
        'data': [
          for (var i = 1; i <= 3; i++)
            {
              'gold_id': 1000 + i,
              'plan': 'PAKET-DENGAN-NAMA-YANG-SANGAT-PANJANG-SEKALI-$i',
              'item_storage_gb': 123.45,
              'item_quota_mb': 1024.0,
              'item_max_mb': 5.0,
              'proof_max_mb': 5.0,
              'upload_gb': 1234.56,
              'download_gb': 1234.56,
              'storage_gb': 1234.56,
              'effective_limit_gb': 9999.0,
              'has_override': true,
            }
        ],
      };
    }
    if (path.endsWith('/storage/admin/usage-summary')) {
      return {
        'data': [
          {
            'environment': 'lingkungan-dengan-nama-sangat-panjang',
            'upload_gb': 1234.56,
            'download_gb': 1234.56,
            'storage_gb': 1234.56,
            'alert_gb': 100,
            'limit_gb': 200,
            'alerted': true,
          }
        ],
      };
    }
    if (path.endsWith('/backup/total-by-environment')) {
      return {
        'data': {'lingkungan-dengan-nama-sangat-panjang': 123456789012}
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
