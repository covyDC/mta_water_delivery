import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mta_water_delivery/screens/auth/admin_login.dart';

void main() {
  testWidgets('AdminLoginPage shows admin and staff login buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminLoginPage()));

    // Expect title text present
    expect(find.textContaining('Admin Login'), findsOneWidget);

    // Buttons should exist (Login as Admin & Login as Staff / Carrier)
    expect(find.text('Login as Admin'), findsOneWidget);
    expect(find.text('Login as Staff / Carrier'), findsOneWidget);
  });
}
