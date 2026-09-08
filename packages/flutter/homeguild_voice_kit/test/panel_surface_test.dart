import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// The panel renders its slots through the SAME view registry the stream uses.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('resolves a pinned slot through the registry', (tester) async {
    await pump(
      tester,
      PanelSurface(
        slots: const [
          PanelSlot(
            view: MessageView(
                viewId: 'checklist', data: {'title': 'Set up your line'}),
            windowId: 'w1',
          ),
        ],
        viewRegistry: {
          'checklist': (context, view) => Text('TASK: ${view.data['title']}'),
        },
      ),
    );
    expect(find.text('TASK: Set up your line'), findsOneWidget);
  });

  testWidgets('renders the empty state when nothing is pinned', (tester) async {
    await pump(tester, const PanelSurface(slots: [], empty: Text('All caught up')));
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder for an unregistered view', (tester) async {
    await pump(
      tester,
      const PanelSurface(
        slots: [PanelSlot(view: MessageView(viewId: 'checklist'), windowId: 'w1')],
      ),
    );
    expect(find.text('[checklist]'), findsOneWidget);
  });
}
