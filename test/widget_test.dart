import 'package:angostura_appv1/main_modular.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Angostura App construye su shell principal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AngosturaApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.title, 'AngosturApp');
    expect(materialApp.routerConfig, isNotNull);
  });
}
