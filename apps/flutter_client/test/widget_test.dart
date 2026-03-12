import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prts_client/main.dart';

void main() {
  testWidgets('Narrow screen shows NavigationBar with 5 tabs',
      (WidgetTester tester) async {
    // Force narrow screen → bottom NavigationBar
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });

  testWidgets('Wide screen shows NavigationRail',
      (WidgetTester tester) async {
    // Force wide screen → NavigationRail
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
