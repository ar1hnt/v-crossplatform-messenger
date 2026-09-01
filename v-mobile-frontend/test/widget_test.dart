import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_mobile_frontend/app/app.dart';

void main() {
  testWidgets('Приложение создаётся', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VMessengerApp()));
    expect(find.byType(VMessengerApp), findsOneWidget);
  });
}
