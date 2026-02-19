import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/text_formatter.dart';

class CurrencyInput extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final Function(double)? onChanged;
  final bool enabled;

  const CurrencyInput({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<CurrencyInput> createState() => _CurrencyInputState();
}

class _CurrencyInputState extends State<CurrencyInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_formatCurrency);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_formatCurrency);
    super.dispose();
  }

  void _formatCurrency() {
    final text = widget.controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) {
      widget.onChanged?.call(0);
      return;
    }

    final value = double.parse(text);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CurrencyInputFormatter(),
      ],
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixText: 'Rp ',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Format with thousand separator
    final formatted = _formatWithSeparator(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithSeparator(String digitsOnly) {
    if (digitsOnly.isEmpty) return '';

    final reversed = digitsOnly.split('').reversed.join('');
    final chunks = <String>[];

    for (var i = 0; i < reversed.length; i += 3) {
      final end = i + 3;
      chunks.add(reversed.substring(i, end > reversed.length ? reversed.length : end));
    }

    return chunks.join('.').split('').reversed.join('');
  }
}
