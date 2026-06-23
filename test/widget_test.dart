// Tests for EscolaConecta App
// Three-dot loader tests and basic widget tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:escola_conecta/widgets/app_loading_error_widgets.dart';

void main() {
  group('AppThreeDotLoader Tests', () {
    testWidgets('renders three dots', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppThreeDotLoader(),
          ),
        ),
      );

      // Should render 3 dots (containers with circle shape)
      final dotContainers = find.byType(Container);
      expect(dotContainers, findsNWidgets(3));
    });

    testWidgets('animates continuously', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppThreeDotLoader(),
          ),
        ),
      );

      // Initial state
      await tester.pump();

      // After some animation time
      await tester.pump(const Duration(milliseconds: 500));

      // Should still be rendering (animation doesn't stop)
      expect(find.byType(AppThreeDotLoader), findsOneWidget);
    });

    testWidgets('respects custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppThreeDotLoader(size: 24),
          ),
        ),
      );

      // Widget should build without errors
      expect(find.byType(AppThreeDotLoader), findsOneWidget);
    });

    testWidgets('respects custom color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppThreeDotLoader(color: Colors.red),
          ),
        ),
      );

      expect(find.byType(AppThreeDotLoader), findsOneWidget);
    });
  });

  group('AppThreeDotOverlay Tests', () {
    testWidgets('shows child when not loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppThreeDotOverlay(
              isLoading: false,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(AppThreeDotLoader), findsNothing);
    });

    testWidgets('shows loader when loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppThreeDotOverlay(
              isLoading: true,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(AppThreeDotLoader), findsOneWidget);
    });

    testWidgets('shows message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppThreeDotOverlay(
              isLoading: true,
              message: 'Loading...',
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });
  });

  group('AppThreeDotSplashLoader Tests', () {
    testWidgets('renders without title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppThreeDotSplashLoader(),
        ),
      );

      expect(find.byType(AppThreeDotLoader), findsOneWidget);
    });

    testWidgets('renders with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppThreeDotSplashLoader(
            title: 'Escola Conecta',
          ),
        ),
      );

      expect(find.text('Escola Conecta'), findsOneWidget);
      expect(find.byType(AppThreeDotLoader), findsOneWidget);
    });

    testWidgets('renders with subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppThreeDotSplashLoader(
            title: 'Escola Conecta',
            subtitle: 'Carregando...',
          ),
        ),
      );

      expect(find.text('Escola Conecta'), findsOneWidget);
      expect(find.text('Carregando...'), findsOneWidget);
    });
  });
}