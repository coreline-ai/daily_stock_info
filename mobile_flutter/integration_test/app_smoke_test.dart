import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: renders root material widget', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Coreline Stock AI'))));
    expect(find.text('Coreline Stock AI'), findsOneWidget);
  });
}
