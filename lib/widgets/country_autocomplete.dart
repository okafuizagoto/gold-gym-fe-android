import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../utils/countries.dart';

/// Emoji bendera dari kode ISO2 ("ID" -> 🇮🇩); kosong kalau bukan 2 huruf.
String flagEmoji(String iso2) {
  final c = iso2.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(c)) return '';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 65));
}

/// Pilihan negara dengan autocomplete: ketik untuk mencari (nama Inggris maupun Indonesia), atau fokus/ketuk
/// panah untuk membuka daftar yang bisa digulir lalu pilih satu negara. Daftar statis seluruh dunia
/// (utils/countries.dart); nama tampil sesuai bahasa aplikasi. [value] = kode ISO2 terpilih ("" = belum memilih).
class CountryAutocomplete extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const CountryAutocomplete({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<CountryAutocomplete> createState() => _CountryAutocompleteState();
}

class _CountryAutocompleteState extends State<CountryAutocomplete> {
  TextEditingController? _ctrl;
  bool _english = false;

  CountryOption? get _selected {
    final v = widget.value.toUpperCase();
    for (final c in countryOptions) {
      if (c.iso2 == v) return c;
    }
    return null;
  }

  String _label(CountryOption c) => _english ? c.en : c.id;

  /// Samakan teks kolom dengan negara terpilih (mis. negara bawaan dari lokal perangkat, atau bahasa berganti).
  void _syncText() {
    final sel = _selected;
    if (sel != null && _ctrl != null && _ctrl!.text != _label(sel)) {
      _ctrl!.text = _label(sel);
    }
  }

  @override
  void didUpdateWidget(covariant CountryAutocomplete old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _syncText();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    _english = lang.isEnglish;
    final sel = _selected;
    final sorted = [...countryOptions]
      ..sort((a, b) => _label(a).compareTo(_label(b)));
    return RawAutocomplete<CountryOption>(
      displayStringForOption: _label,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty || (sel != null && _label(sel).toLowerCase() == q)) {
          return sorted; // kosong / sudah terpilih: tampilkan seluruh daftar
        }
        return sorted.where((c) =>
            c.en.toLowerCase().contains(q) ||
            c.id.toLowerCase().contains(q) ||
            c.iso2.toLowerCase() == q);
      },
      onSelected: (c) => widget.onChanged(c.iso2),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        _ctrl = controller;
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncText());
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: lang.get('Country', 'Negara'),
            hintText:
                lang.get('Type or pick a country', 'Ketik atau pilih negara'),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(sel == null ? '🌐' : flagEmoji(sel.iso2),
                  style: const TextStyle(fontSize: 20)),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_drop_down_rounded),
              onPressed: () {
                // buka daftar penuh: kosongkan teks lalu fokus
                controller.clear();
                widget.onChanged('');
                focusNode.requestFocus();
              },
            ),
          ),
          onChanged: (text) {
            // mengetik setelah memilih membatalkan pilihan sampai memilih lagi dari daftar
            if (sel != null && text != _label(sel)) widget.onChanged('');
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final c = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: Text(flagEmoji(c.iso2),
                        style: const TextStyle(fontSize: 20)),
                    title: Text(_label(c)),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
