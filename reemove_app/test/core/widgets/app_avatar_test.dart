import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/widgets/app_avatar.dart';

void main() {
  group('AppAvatar', () {
    testWidgets('shows initials when image url is missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppAvatar(displayName: 'Mustafa Abualhija')),
        ),
      );

      expect(find.text('MA'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('falls back to initials when network image fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              displayName: 'ReeMove Athlete',
              imageUrl: 'https://invalid.example/avatar.jpg',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('RA'), findsOneWidget);
    });
  });
}
