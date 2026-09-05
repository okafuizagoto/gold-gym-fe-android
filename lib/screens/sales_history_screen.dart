import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../services/sales_api.dart';
import '../models/sales_model.dart';
import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../utils/debouncer.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import 'proof_viewer_screen.dart';
import 'sales_detail_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _salesApi = SalesApi();
  final _debouncer = Debouncer(milliseconds: 400);
  final _searchController = TextEditingController();

  List<SaleHistoryModel> _sales = [];
  bool _isLoading = false;
  String? _printingSaleId;
  String? _markingSaleId;
  String? _loadingProofSaleId;
  bool _isSeller = true;
  // admin bisa menyembunyikan tombol "Bukti transfer" (global/per outlet/per
  // user) lewat menu Akses Admin > Visibilitas Bukti Pembayaran.
  bool _proofFeatureEnabled = true;

  int _page = 1;
  final int _length = 20;
  int _totalPage = 1;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadSales();
  }

  Future<void> _loadRole() async {
    final role = await Storage.get(AppConstants.userRoleKey) ??
        AppConstants.roleSeller;
    if (mounted) {
      setState(() => _isSeller = role != AppConstants.roleBuyer);
    }
    // gagal load dianggap aktif (default aman: tidak menyembunyikan fitur
    // yang sedang berjalan hanya karena request gagal)
    bool proofEnabled = true;
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final r = await _salesApi.getProofVisibility(outcode);
      if (r.statusCode == 200) {
        proofEnabled = jsonDecode(r.body)['enabled'] != false;
      }
    } catch (_) {}
    if (mounted) setState(() => _proofFeatureEnabled = proofEnabled);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _loadSales({bool append = false}) async {
    setState(() => _isLoading = true);
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final response = await _salesApi.getAllSales(
          _searchController.text, outcode, _page, _length);

      if (response.statusCode == 200) {
        final pagination =
            SaleHistoryPagination.fromJson(jsonDecode(response.body));
        setState(() {
          _totalPage = pagination.totalPage;
          if (append) {
            _sales = [..._sales, ...pagination.data];
          } else {
            _sales = pagination.data;
          }
        });
      } else {
        if (mounted) Toast.error(context, 'Gagal memuat history sales');
      }
    } catch (e) {
      debugPrint('Error loading sales history: $e');
      if (mounted) Toast.error(context, 'Gagal memuat history sales');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printReceipt(SaleHistoryModel sale) async {
    setState(() => _printingSaleId = sale.saleId);
    try {
      final pdfBytes = await _salesApi.getReceiptPdf(sale.saleId);
      if (pdfBytes == null) {
        if (mounted) Toast.error(context, 'Nota tidak ditemukan');
        return;
      }
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      if (mounted) Toast.error(context, 'Gagal cetak nota');
    } finally {
      if (mounted) setState(() => _printingSaleId = null);
    }
  }

  /// Lihat foto bukti pembayaran transfer milik nota ini (bisa di-download
  /// ke galeri dari layar penampil). Transaksi TUNAI tidak pernah punya bukti
  /// transfer -- langsung diberi tahu tanpa perlu query ke server.
  Future<void> _viewProofs(SaleHistoryModel sale) async {
    if (sale.salePayType == AppConstants.paymentCash) {
      Toast.info(context,
          'Transaksi ini menggunakan metode tunai, sehingga tidak memiliki bukti transfer.');
      return;
    }
    setState(() => _loadingProofSaleId = sale.saleId);
    try {
      final response = await _salesApi.getPaymentProofs(sale.saleId);
      if (response.statusCode != 200) {
        if (mounted) Toast.error(context, 'Gagal memuat bukti pembayaran');
        return;
      }
      final data = jsonDecode(response.body);
      final proofs = ((data['data'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (proofs.isEmpty) {
        if (mounted) {
          Toast.error(
              context, 'Bukti pembayaran belum tersedia untuk transaksi ini.');
        }
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProofViewerScreen(
            saleTrancnum: sale.saleTrancnum,
            proofs: proofs,
          ),
        ),
      );
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memuat bukti pembayaran');
    } finally {
      if (mounted) setState(() => _loadingProofSaleId = null);
    }
  }

  /// Admin/penjual mengubah transaksi BELUM LUNAS menjadi LUNAS
  /// (misal pembeli menandai belum bayar tapi ternyata sudah bayar).
  Future<void> _markPaid(SaleHistoryModel sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tandai Lunas'),
        content: Text(
            'Ubah status ${sale.saleTrancnum} menjadi LUNAS? Pembayaran dianggap pas sebesar ${TextFormatter.formatRupiah(sale.saleTranstotal)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('TANDAI LUNAS'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _markingSaleId = sale.saleId);
    try {
      final response = await _salesApi.markPaid(sale.saleId);
      if (response.statusCode == 200) {
        if (mounted) Toast.success(context, 'Transaksi ditandai LUNAS');
        await _loadSales();
      } else {
        String message = 'Gagal mengubah status';
        try {
          message = jsonDecode(response.body)['error'] ?? message;
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal mengubah status');
    } finally {
      if (mounted) setState(() => _markingSaleId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
          title: langProvider.get('Sales History', 'History Penjualan'),
        ),
        drawer: const AppDrawer(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: langProvider.get(
                      'Search receipt no / customer', 'Cari no nota / pembeli'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) {
                  _debouncer.run(() {
                    _page = 1;
                    _loadSales();
                  });
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _page = 1;
                  await _loadSales();
                },
                child: _isLoading && _sales.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _sales.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  langProvider.get('No transactions yet',
                                      'Belum ada transaksi'),
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount:
                                _sales.length + (_page < _totalPage ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _sales.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: OutlinedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () {
                                              _page++;
                                              _loadSales(append: true);
                                            },
                                      child: Text(langProvider.get(
                                          'Load more', 'Muat lagi')),
                                    ),
                                  ),
                                );
                              }
                              return _buildSaleCard(
                                  _sales[index], langProvider);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleCard(SaleHistoryModel sale, LanguageProvider langProvider) {
    final dateStr = sale.saleTransdate == null
        ? '-'
        : DateFormat('dd-MM-yyyy').format(sale.saleTransdate!);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              sale.isPaid ? Colors.green[100] : Colors.orange[100],
          child: Icon(
            sale.isPaid ? Icons.check : Icons.hourglass_bottom,
            color: sale.isPaid ? Colors.green[800] : Colors.orange[800],
          ),
        ),
        title: Text(
          sale.saleTrancnum,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateStr ${TextFormatter.formatTimeHms(sale.saleTranstime)}'),
            Text(TextFormatter.formatRupiah(sale.saleTranstotal)),
            if (sale.saleSalescustomer.isNotEmpty)
              Text('${langProvider.get('Customer', 'Pembeli')}: '
                  '${sale.saleSalescustomer}'),
            if (sale.hasMeja)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_bar, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Meja: ${sale.saleMejaNames}',
                      style: TextStyle(color: Colors.grey[700])),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              color: Colors.indigo[700],
              tooltip: langProvider.get('Sale detail', 'Detail transaksi'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SalesDetailScreen(saleId: sale.saleId),
                ),
              ),
            ),
            // lihat & download foto bukti pembayaran transfer — disembunyikan
            // jika admin menonaktifkan fitur ini (Akses Admin)
            if (_proofFeatureEnabled)
              _loadingProofSaleId == sale.saleId
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.image),
                      color: Colors.teal[700],
                      tooltip: langProvider.get(
                          'Payment proof', 'Bukti transfer'),
                      onPressed: () => _viewProofs(sale),
                    ),
            if (_isSeller && !sale.isPaid)
              _markingSaleId == sale.saleId
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.price_check),
                      color: Colors.green[700],
                      tooltip: langProvider.get('Mark as paid', 'Tandai lunas'),
                      onPressed: () => _markPaid(sale),
                    ),
            _printingSaleId == sale.saleId
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.print),
                    color: Colors.blue[700],
                    tooltip: langProvider.get('Print receipt', 'Cetak nota'),
                    onPressed: () => _printReceipt(sale),
                  ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
