// DDE-Mart handyman app — smoke test (original).

import 'package:dde_handyman/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to handyman sign-in offline', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DdeHandymanApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
