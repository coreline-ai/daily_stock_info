import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app_entire/app/bootstrap/bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app smoke test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BootstrapApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Coreline'), findsOneWidget);
    expect(find.text('Top Picks'), findsOneWidget);
  });
}
