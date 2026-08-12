import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('HealthcareApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HealthcareApp());
    expect(find.byType(HealthcareApp), findsOneWidget);
  });
}
