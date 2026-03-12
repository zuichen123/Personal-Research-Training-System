import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prts_client/widgets/common/app_button.dart';
import 'package:prts_client/widgets/common/app_text_field.dart';

void main() {
  group('AppButton', () {
    testWidgets('shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Test',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test'), findsNothing);
    });

    testWidgets('shows text when isLoading is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Test',
              onPressed: () {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('AppTextField', () {
    testWidgets('displays error text when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: TextEditingController(),
              errorText: 'Error message',
            ),
          ),
        ),
      );

      expect(find.text('Error message'), findsOneWidget);
    });

    testWidgets('calls validator function', (tester) async {
      var validatorCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: AppTextField(
                controller: TextEditingController(),
                validator: (value) {
                  validatorCalled = true;
                  return value?.isEmpty ?? true ? 'Required' : null;
                },
              ),
            ),
          ),
        ),
      );

      final formState = tester.state<FormState>(find.byType(Form));
      formState.validate();

      expect(validatorCalled, true);
    });
  });
}
