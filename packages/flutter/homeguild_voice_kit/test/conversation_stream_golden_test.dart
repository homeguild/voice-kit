import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

import 'fixtures/scenarios.dart';

/// Screen-level goldens of the conversation surface, one per [Scenario]. One
/// capture, many uses: a visual-regression gate, a catalog/view-map entry (the
/// PNG under test/goldens/), and — with the scenario's narrative — a user-doc
/// and agent-support entry (see catalog_generate_test.dart).
///
/// Regenerate the images with:  flutter test --update-goldens
void main() {
  setUpAll(() async => loadAppFonts());

  for (final s in Scenarios.all) {
    testGoldens('conversation surface — ${s.title}', (tester) async {
      await tester.pumpWidgetBuilder(
        Scaffold(body: ConversationStream(messages: s.messages)),
        wrapper: materialAppWrapper(theme: ThemeData.light(useMaterial3: true)),
        surfaceSize: const Size(390, 844),
      );
      await screenMatchesGolden(tester, s.id);
    });
  }
}
