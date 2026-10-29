// Dropdown wilayah dengan NAMA SANGAT PANJANG pada HP kecil + font besar: tidak boleh meluap.
// (Bug asal: baris Provinsi form Daftar Outlet overflow 8.6px karena DropdownButtonFormField tanpa
// isExpanded.) Audit layar penuh memakai data kosong sehingga bug ini lolos -- tes ini menutupnya.
//
// Jalankan: flutter test test/location_dropdown_overflow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gold_gym_fe_android/config/theme.dart';
import 'package:gold_gym_fe_android/models/location_model.dart';
import 'package:gold_gym_fe_android/widgets/location_picker.dart';

LocationDivision div(int id, String name) => LocationDivision(
    divisionId: id, countryId: 1, level: 1, officialCode: '$id', name: name);

final longNames = [
  div(1, 'Daerah Khusus Ibukota Jakarta'),
  div(2, 'Kepulauan Bangka Belitung'),
  div(3,
      'Kelurahan Dengan Nama Yang Sangat Panjang Sekali Sampai Melebihi Lebar Layar HP Kecil'),
];

void main() {
  const sizes = {
    'hp-kecil-360': Size(360, 640),
    'hp-umum-412': Size(412, 915),
  };
  for (final entry in sizes.entries) {
    for (final scale in [1.0, 1.3, 1.5]) {
      for (final selected in [null, 1, 3]) {
        testWidgets(
            'dropdown nama panjang tidak overflow @ ${entry.key} font ${scale}x pilihan=$selected',
            (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LocationDropdownField(
                  label: 'Provinsi',
                  options: longNames,
                  value: selected,
                  onChanged: (_) {},
                ),
              ),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'dropdown meluap @ ${entry.key} font ${scale}x');

          // buka daftar pilihan: item panjang juga tidak boleh meluap
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'daftar pilihan meluap @ ${entry.key} font ${scale}x');
        });
      }
    }
  }
}
