import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voiceapp/main.dart';

/// Integration test scaffold
///
/// This is a minimal smoke test that verifies the app can launch
/// and render its main screen without crashing.
///
/// Future tests can be added here to verify end-to-end workflows:
/// - Opening settings and saving configuration
/// - Starting/stopping a conversation
/// - Clearing messages
/// - Adding/removing OpenClaw instances
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceApp Integration Tests', () {
    testWidgets('app launches and displays main screen with app bar', (
      tester,
    ) async {
      await tester.pumpWidget(const VoiceApp());
      await tester.pumpAndSettle();

      expect(find.text('Voice Chat'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
