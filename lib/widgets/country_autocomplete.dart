import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/location_model.dart';
import '../providers/language_provider.dart';
import '../services/location_api.dart';

/// Emoji bendera dari kode ISO2 ("ID" -> 🇮🇩); kosong kalau bukan 2 huruf.
String flagEmoji(String iso2) {
  final c = iso2.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(c)) return '';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 65));
}

/// Pilihan negara dengan autocomplete: ketik untuk mencari, atau fokus/ketuk panah untuk membuka daftar yang
/// bisa digulir lalu pilih satu negara. Daftar dari /v2/location/countries (publik, tanpa token).
/// [value] = kode ISO2 terpilih ("" = belum memilih); [onLoaded] dipanggil begitu daftar selesai dimuat.
class CountryAutocomplete extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool>? onLoaded;
  final bool enabled;

  const CountryAutocomplete({
    super.key,
    required this.value,
    required this.onChanged,
    this.onLoaded,
    this.enabled = true,
  });

  @override
  State<CountryAutocomplete> createState() => _CountryAutocompleteState();
}

class _CountryAutocompleteState extends State<CountryAutocomplete> {
  List<LocationCountry> _countries = [];
  bool _loading = true;
  TextEditingController? _ctrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var ok = false;
    try {
      final resp = await LocationApi().getCountries();
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body)['data'];
        if (data is List) {
          _countries = data
              .map((e) => LocationCountry.fromJson(e as Map<String, dynamic>))
              .where((c) => c.iso2.length == 2 && c.name.isNotEmpty)
              .toList();
          ok = _countries.isNotEmpty;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
    _syncText();
    widget.onLoaded?.call(ok);
  }

  LocationCountry? get _selected {
    final v = widget.value.toUpperCase();
    for (final c in _countries) {
      if (c.iso2.toUpperCase() == v) return c;
    }
    return null;
  }

  /// Samakan teks kolom dengan negara terpilih (mis. negara bawaan dari lokal perangkat).
  void _syncText() {
    final sel = _selected;
    if (sel != null && _ctrl != null && _ctrl!.text != sel.name) {
      _ctrl!.text = sel.name;
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
    final sel = _selected;
    return RawAutocomplete<LocationCountry>(
      displayStringForOption: (c) => c.name,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty || (sel != null && sel.name.toLowerCase() == q)) {
          return _countries; // kosong / sudah terpilih: tampilkan seluruh daftar
        }
        return _countries.where((c) =>
            c.name.toLowerCase().contains(q) || c.iso2.toLowerCase() == q);
      },
      onSelected: (c) => widget.onChanged(c.iso2.toUpperCase()),
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
            hintText: lang.get('Type or pick a country', 'Ketik atau pilih negara'),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(sel == null ? '🌐' : flagEmoji(sel.iso2),
                  style: const TextStyle(fontSize: 20)),
            ),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
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
            if (sel != null && text != sel.name) widget.onChanged('');
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
                    title: Text(c.name),
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
