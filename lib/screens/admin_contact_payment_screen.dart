import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/manual_pay_model.dart';
import '../services/manual_pay_api.dart';
import '../utils/support.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// ADMIN: kontak bantuan (tombol WhatsApp + Tentang Kami) dan rekening bayar langganan lewat transfer (2026-11-18).
/// Nilai kosong = tidak ditampilkan ke pengguna. Padanan web: pages/admin-kontak-pembayaran.
class AdminContactPaymentScreen extends StatefulWidget {
  const AdminContactPaymentScreen({super.key});

  @override
  State<AdminContactPaymentScreen> createState() => _AdminContactPaymentScreenState();
}

class _AdminContactPaymentScreenState extends State<AdminContactPaymentScreen> {
  final _api = ManualPayApi();
  bool _loading = true;
  String _saving = '';
  final _wa = TextEditingController();
  final _name = TextEditingController();
  final _hours = TextEditingController();
  final _email = TextEditingController();
  bool _bankOn = false;
  final _bankName = TextEditingController();
  final _accNo = TextEditingController();
  final _accName = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_wa, _name, _hours, _email, _bankName, _accNo, _accName, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _data(String body) {
    final d = (jsonDecode(body) as Map)['data'];
    return d is Map ? d.cast<String, dynamic>() : null;
  }

  String _err(String body, String fallback) {
    try {
      final e = (jsonDecode(body) as Map)['error'];
      if (e is String && e.isNotEmpty) return e;
    } catch (_) {}
    return fallback;
  }

  void _fillContact(SupportContact c) {
    _wa.text = c.whatsapp;
    _name.text = c.name;
    _hours.text = c.hours;
    _email.text = c.email;
  }

  void _fillBank(BankInfo b) {
    _bankOn = b.enabled;
    _bankName.text = b.bankName;
    _accNo.text = b.accountNo;
    _accName.text = b.accountName;
    _note.text = b.note;
  }

  Future<void> _load() async {
    try {
      final c = await _api.contact();
      final b = await _api.bank();
      if (!mounted) return;
      if (c.statusCode == 200) {
        final d = _data(c.body);
        if (d != null) _fillContact(SupportContact.fromJson(d));
      }
      if (b.statusCode == 200) {
        final d = _data(b.body);
        if (d != null) _fillBank(BankInfo.fromJson(d));
      } else {
        Toast.error(context, _err(b.body, 'Gagal memuat rekening'));
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat pengaturan. Periksa koneksi internet Anda.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveContact() async {
    setState(() => _saving = 'contact');
    try {
      final r = await _api.setContact(SupportContact(
              whatsapp: _wa.text.trim(), name: _name.text.trim(), hours: _hours.text.trim(), email: _email.text.trim())
          .toJson());
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = _data(r.body);
        if (d != null) setState(() => _fillContact(SupportContact.fromJson(d)));
        await Support.load(force: true);
        if (mounted) Toast.success(context, 'Kontak bantuan disimpan');
      } else {
        Toast.error(context, _err(r.body, 'Gagal menyimpan kontak'));
      }
    } finally {
      if (mounted) setState(() => _saving = '');
    }
  }

  Future<void> _saveBank() async {
    setState(() => _saving = 'bank');
    try {
      final r = await _api.setBank(BankInfo(
              enabled: _bankOn,
              bankName: _bankName.text.trim(),
              accountNo: _accNo.text.trim(),
              accountName: _accName.text.trim(),
              note: _note.text.trim())
          .toJson());
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = _data(r.body);
        if (d != null) setState(() => _fillBank(BankInfo.fromJson(d)));
        Toast.success(context, 'Rekening transfer disimpan');
      } else {
        Toast.error(context, _err(r.body, 'Gagal menyimpan rekening'));
      }
    } finally {
      if (mounted) setState(() => _saving = '');
    }
  }

  Widget _field(TextEditingController c, String label, {int? max, String? hint, TextInputType? type, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLength: max,
          maxLines: lines,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, hintText: hint, counterText: ''),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Kontak & Pembayaran'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: 'Kontak bantuan',
                    icon: Icons.contact_support_outlined,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text(
                          'Dipakai tombol "Bantuan via WhatsApp" dan halaman Tentang Kami di web dan Android. '
                          'Kosongkan nomor untuk menyembunyikan tombol.',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 10),
                      _field(_wa, 'Nomor WhatsApp', hint: '0812xxxxxxxx', type: TextInputType.phone),
                      _field(_name, 'Nama penanggung jawab', max: 60),
                      _field(_hours, 'Jam layanan', max: 120, hint: 'Senin-Sabtu 09.00-17.00 WIB'),
                      _field(_email, 'Email bantuan', max: 120, type: TextInputType.emailAddress),
                      ElevatedButton(
                        onPressed: _saving.isEmpty ? _saveContact : null,
                        child: Text(_saving == 'contact' ? 'Menyimpan...' : 'Simpan kontak'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Bayar langganan lewat transfer bank',
                    icon: Icons.account_balance_outlined,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text(
                          'Hanya tampil di web. Aplikasi Android dari Google Play tetap memakai Google Play Billing '
                          '(kebijakan Google). Setujui pembayaran di menu Konfirmasi Pembayaran setelah uang terlihat '
                          'di mutasi rekening.',
                          style: TextStyle(fontSize: 12)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Buka pembayaran lewat transfer'),
                        value: _bankOn,
                        onChanged: (v) => setState(() => _bankOn = v),
                      ),
                      _field(_bankName, 'Nama bank', max: 60),
                      _field(_accNo, 'Nomor rekening', max: 40, type: TextInputType.number),
                      _field(_accName, 'Nama pemilik rekening', max: 100),
                      _field(_note, 'Catatan untuk pembayar (opsional)', max: 300, lines: 2),
                      ElevatedButton(
                        onPressed: _saving.isEmpty ? _saveBank : null,
                        child: Text(_saving == 'bank' ? 'Menyimpan...' : 'Simpan rekening'),
                      ),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }
}
