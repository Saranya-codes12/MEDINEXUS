import 'package:flutter_test/flutter_test.dart';
import 'package:medinexus_mobile/main.dart';

void main() {
  testWidgets('MediNexus app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const MediNexusApp());

    expect(find.byType(MediNexusApp), findsOneWidget);
  });
}