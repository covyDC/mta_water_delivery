import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mta_water_delivery/widgets/driver_selection_dialog.dart';

void main() {
  testWidgets('DriverSelectionDialog returns selected id when assigned', (tester) async {
    final drivers = [
      {'id': 'driver1', 'name': 'Alice', 'phone': '111', 'status': 'online'},
      {'id': 'driver2', 'name': 'Bob', 'phone': '222', 'status': 'online'},
    ];

    String? selected;

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      return Center(
        child: ElevatedButton(
          onPressed: () async {
            selected = await showDialog<String?>(context: ctx, builder: (_) => DriverSelectionDialog(drivers: drivers));
          },
          child: const Text('Open'),
        ),
      );
    })));

    // Open the dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Assign to Driver'), findsOneWidget);

    // select Alice and press Assign
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    expect(selected, equals('driver1'));
  });

  testWidgets('DriverSelectionDialog shows full name when only first/last provided', (tester) async {
    final drivers = [
      {'id': 'driver1', 'firstName': 'Charles', 'lastName': 'Doyle', 'phone': '111', 'status': 'online'},
    ];

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      return Center(
        child: ElevatedButton(
          onPressed: () async {
            await showDialog<String?>(context: ctx, builder: (_) => DriverSelectionDialog(drivers: drivers));
          },
          child: const Text('Open'),
        ),
      );
    })));

    // Open the dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Assign to Driver'), findsOneWidget);

    // The composed name should be visible
    expect(find.text('Charles Doyle'), findsOneWidget);
  });
}
