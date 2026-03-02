import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/main.dart';

void main() {
  testWidgets('App boots with main tab navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Questions'), findsWidgets);
    expect(find.text('Mistakes'), findsWidgets);
    expect(find.text('Practice'), findsWidgets);
    expect(find.text('Resources'), findsWidgets);
    expect(find.text('Plans'), findsWidgets);
    expect(find.text('Focus'), findsWidgets);
  });
}
