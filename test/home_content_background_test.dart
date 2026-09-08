import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neki/core/painters/hanging_lanterns_painter.dart';
import 'package:neki/core/painters/islamic_pattern_painter.dart';
import 'package:neki/core/widgets/home_content_background.dart';

void main() {
  group('IslamicPatternPainter', () {
    test('paints across various hours without throwing', () {
      final hours = [5, 6, 12, 16, 18, 22];

      for (final hour in hours) {
        final painter = IslamicPatternPainter(hour: hour);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(400, 800);

        expect(() => painter.paint(canvas, size), returnsNormally);
      }
    });

    test('handles zero or negative size gracefully', () {
      const painter = IslamicPatternPainter(hour: 12);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      expect(() => painter.paint(canvas, const Size(-10, -10)), returnsNormally);
    });

    test('shouldRepaint detects changes', () {
      const p1 = IslamicPatternPainter(hour: 5);
      const p2 = IslamicPatternPainter(hour: 12);
      const p3 = IslamicPatternPainter(hour: 5, opacity: 0.1);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isTrue);
      expect(p1.shouldRepaint(p1), isFalse);
    });
  });

  group('HangingLanternsPainter', () {
    test('paints smoothly across animation phases', () {
      final phases = [0.0, 0.25, 0.5, 0.75, 1.0];

      for (final phase in phases) {
        final painter = HangingLanternsPainter(animationValue: phase, hour: 20);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(400, 800);

        expect(() => painter.paint(canvas, size), returnsNormally);
      }
    });

    test('shouldRepaint responds to animation value changes', () {
      const p1 = HangingLanternsPainter(animationValue: 0.1, hour: 12);
      const p2 = HangingLanternsPainter(animationValue: 0.2, hour: 12);
      const p3 = HangingLanternsPainter(animationValue: 0.1, hour: 12);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });
  });

  group('HomeContentBackground Widget', () {
    testWidgets('renders child and background layers properly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HomeContentBackground(
                child: Text('Test Content Area'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Content Area'), findsOneWidget);
      expect(find.byType(HomeContentBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
