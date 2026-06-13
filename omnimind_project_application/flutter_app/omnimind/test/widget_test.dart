// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnimind/main.dart';

void main() {
  testWidgets('OmniMind app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OmniMindApp());
    
    // Verify that splash screen or login screen shows
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
