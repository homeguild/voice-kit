import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fixtures/scenarios.dart';

/// Generates the two projections of the scenario library from the SAME source
/// (test/fixtures/scenarios.dart + the goldens):
///   • catalog/view-map.md   — human user-docs (narrative + real screenshot)
///   • catalog/support-kb.json — agentic-support knowledge (retrievable units)
///
/// Run it like --update-goldens:  flutter test test/catalog_generate_test.dart
/// The docs are born from passing tests + regenerated screenshots, so they stay
/// current with the build instead of drifting.
void main() {
  test('generate the view-map + support KB from the scenarios', () {
    final md = StringBuffer()
      ..writeln('# View map')
      ..writeln()
      ..writeln('_Generated from the scenario library. Each entry is a verified, '
          'screenshotted, described state of the product._')
      ..writeln();

    final kb = <Map<String, Object?>>[];

    for (final s in Scenarios.all) {
      md
        ..writeln('## ${s.title}')
        ..writeln('_${s.feature}_')
        ..writeln()
        ..writeln('![${s.id}](../test/goldens/${s.golden})')
        ..writeln()
        ..writeln(s.narrative)
        ..writeln()
        ..writeln('**What this shows**')
        ..writeln();
      for (final point in s.shows) {
        md.writeln('- $point');
      }
      md.writeln();

      kb.add({
        'id': s.id,
        'title': s.title,
        'feature': s.feature,
        'narrative': s.narrative,
        'shows': s.shows,
        'screenshot': 'test/goldens/${s.golden}',
      });
    }

    Directory('catalog').createSync(recursive: true);
    File('catalog/view-map.md').writeAsStringSync(md.toString());
    File('catalog/support-kb.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(kb));

    // Sanity: the corpus isn't empty.
    expect(Scenarios.all, isNotEmpty);
  });
}
