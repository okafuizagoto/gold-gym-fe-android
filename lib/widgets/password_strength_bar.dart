import 'package:flutter/material.dart';
import '../utils/password_strength.dart';

const _levelColors = [
  Color(0xFFD32F2F),
  Color(0xFFED6C02),
  Color(0xFF2E7D32),
  Color(0xFF1B5E20),
];

/// Meter kekuatan password (4 segmen) + daftar syarat. Kosong = tidak tampil.
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  const PasswordStrengthBar({super.key, required this.password});

  Widget _rule(BuildContext context, bool ok, String text,
      {bool optional = false}) {
    final color = ok ? const Color(0xFF2E7D32) : Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              optional ? '$text (opsional, menambah kuat)' : text,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final ev = evaluatePassword(password);
    final color = _levelColors[ev.level];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= ev.level ? color : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Kekuatan password: ${ev.label}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
          if (ev.hint.isNotEmpty)
            Text(ev.hint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          _rule(context, ev.hasMinLength, 'Minimal 6 karakter'),
          _rule(context, ev.hasUpper, 'Huruf besar (A-Z)'),
          _rule(context, ev.hasLower, 'Huruf kecil (a-z)'),
          _rule(context, ev.hasDigit, 'Angka (0-9)'),
          _rule(context, ev.hasSymbol, 'Simbol (# ! @ dll.)', optional: true),
        ],
      ),
    );
  }
}
