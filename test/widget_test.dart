import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:al_adhan/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the prayer times screen shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PrayerTimesApp());

    expect(find.text('Prayer Times'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('shows default options selections', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: OptionsScreen(
          initialMethod: defaultCalculationMethod,
          initialSchool: defaultSchool,
        ),
      ),
    );

    expect(find.text('Options'), findsOneWidget);
    expect(find.text('0 - Shafi'), findsOneWidget);
    expect(
      find.text('1 - University of Islamic Sciences, Karachi'),
      findsOneWidget,
    );
  });
}
