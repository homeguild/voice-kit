import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

import 'fixtures/scenarios.dart';

/// Screen-level golden of the conversation surface. One capture, three uses:
/// a visual-regression test (it gates), a catalog/view-map entry (the PNG under
/// test/goldens/), and a design reference. The scenario data is deterministic,
/// so the screenshot is stable enough to fail CI on.
///
/// Regenerate the images with:  flutter test --update-goldens
void main() {
  setUpAll(() async => loadAppFonts());

  testGoldens('conversation surface — weekend callout (pending draft + aside)',
      (tester) async {
    await tester.pumpWidgetBuilder(
      Scaffold(
        body: ConversationStream(messages: Scenarios.weekendCallout),
      ),
      wrapper: materialAppWrapper(theme: ThemeData.light(useMaterial3: true)),
      surfaceSize: const Size(390, 844), // a phone
    );
    await screenMatchesGolden(tester, 'weekend_callout');
  });
}
