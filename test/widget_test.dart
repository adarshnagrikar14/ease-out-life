// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easeoutlife/theme/app_colors.dart';

void main() {
  testWidgets(
    'Palette primaryPurple is used as app primary',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.dark(
            primary: AppColors.primaryPurple,
          ),
        ),
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      final theme = Theme.of(
        tester.element(find.byType(Scaffold)),
      );

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.primaryPurple);
    },
  );
}
