import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/manual_pay_model.dart';
import '../providers/language_provider.dart';
import '../services/offline/sales_outbox.dart';
import '../utils/support.dart';

/// Tombol "Bantuan via WhatsApp" (2026-11-18). Tidak dirender bila admin belum mengisi nomor dukungan, sehingga tidak
/// pernah ada nomor contoh di layar. Padanan web: components/SupportWhatsAppButton.tsx.
class SupportWhatsAppButton extends StatefulWidget {
  final String? label;
  final String topic;
  final String extra;
  final bool filled;
  final bool expand;
  const SupportWhatsAppButton({
    super.key,
    this.label,
    this.topic = '',
    this.extra = '',
    this.filled = false,
    this.expand = false,
  });

  @override
  State<SupportWhatsAppButton> createState() => _SupportWhatsAppButtonState();
}

class _SupportWhatsAppButtonState extends State<SupportWhatsAppButton> {
  SupportContact? _c = Support.cached;

  @override
  void initState() {
    super.initState();
    Support.load().then((v) {
      if (mounted) setState(() => _c = v);
    });
  }

  Future<void> _open() async {
    final ob = SalesOutbox.instance;
    final text = await Support.message(
        topic: widget.topic,
        pending: ob.pendingCount,
        failed: ob.failedCount,
        extra: widget.extra);
    await Support.open(_c!.whatsapp, text);
  }

  @override
  Widget build(BuildContext context) {
    if (_c == null || _c!.whatsapp.isEmpty) return const SizedBox.shrink();
    const green = Color(0xFF15803D);
    const icon = Icon(Icons.chat_rounded, size: 18);
    final lang = context.watch<LanguageProvider>();
    final label = Text(
        widget.label ?? lang.get('Help via WhatsApp', 'Bantuan via WhatsApp'));
    final btn = widget.filled
        ? ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: green, foregroundColor: Colors.white),
            onPressed: _open,
            icon: icon,
            label: label)
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: green),
            onPressed: _open,
            icon: icon,
            label: label);
    return widget.expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
