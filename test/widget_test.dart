import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/main.dart';

void main() {
  testWidgets('app starts and shows its name', (tester) async {
    await tester.pumpWidget(const GariPathApp());

    expect(find.text('GariPath'), findsOneWidget);
  });
}
