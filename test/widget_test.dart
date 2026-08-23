import 'package:flutter_test/flutter_test.dart';

import 'package:amantak2/main.dart';

void main() {
  testWidgets('Security Manager starts on the splash screen', (tester) async {
    await tester.pumpWidget(const SecurityManagerApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Security Guard Manager'), findsOneWidget);
  });
}
