import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gold_gym_fe_android/main.dart';

void main() {
  testWidgets('aplikasi mulai di halaman login', (WidgetTester tester) async {
    dotenv.testLoad(fileInput: 'ENVIRONMENT=local\nBASE_API_URL=http://127.0.0.1:9');
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp(startRoute: '/login'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
