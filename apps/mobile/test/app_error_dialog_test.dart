import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/widgets/app_error_dialog.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('showAppErrorDialog shows the message in a dialog',
      (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppErrorDialog(
              context,
              'CTC / Cedula number is required.',
              title: 'Cannot submit yet',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Cannot submit yet'), findsOneWidget);
    expect(find.text('CTC / Cedula number is required.'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('showFormValidationErrors names the first invalid field',
      (tester) async {
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      host(
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Plate number'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Plate number is required.'
                    : null,
              ),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showFormValidationErrors(context, formKey.currentState),
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Plate number is required.'), findsNWidgets(2));
  });
}
