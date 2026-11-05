import 'dart:async';

import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockChatHistory extends Mock implements ChatHistoryNotifier {}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required List<Map<String, dynamic>> messages,
  bool finishLoading = true,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final history = MockChatHistory();
  when(() => history.messages).thenReturn(messages);
  if (finishLoading) {
    when(() => history.loadAll()).thenAnswer((_) async {});
  } else {
    when(() => history.loadAll()).thenAnswer((_) => Completer<void>().future);
  }

  await tester.pumpWidget(
    buildTestMaterialApp(const Scaffold(body: Placeholder())),
  );
  unawaited(
    showDialog<void>(
      context: tester.element(find.byType(Placeholder)),
      builder: (context) => ConversationPinnedMessagesDialog(
        title: 'Pinned Tester pinned messages',
        history: history,
      ),
    ),
  );
  await tester.pump();
  // The dialog starts by loading the older pages; once that future completes
  // its setState needs one more frame. A pending load never settles, so only
  // wait for a quiet frame when the stub is allowed to finish.
  if (finishLoading) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('says so plainly when nothing is pinned', (tester) async {
    await _pumpDialog(tester, messages: <Map<String, dynamic>>[]);

    expect(
      find.text('No pinned messages in this conversation yet.'),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('lists only the pinned messages, oldest first', (tester) async {
    await _pumpDialog(
      tester,
      messages: [
        {'id': 'm1', 'content': 'First pinned note', 'is_pinned': true},
        {'id': 'm2', 'content': 'Just a normal message'},
        {'id': 'm3', 'content': 'Second pinned note', 'pinned': true},
      ],
    );

    expect(find.text('First pinned note'), findsOneWidget);
    expect(find.text('Second pinned note'), findsOneWidget);
    expect(find.text('Just a normal message'), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(2));

    final first = tester.getTopLeft(find.text('First pinned note')).dy;
    final second = tester.getTopLeft(find.text('Second pinned note')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('shows a loading row while older pages load', (tester) async {
    await _pumpDialog(
      tester,
      messages: <Map<String, dynamic>>[],
      finishLoading: false,
    );

    expect(find.text('Loading older messages…'), findsOneWidget);
    expect(
      find.text('No pinned messages in this conversation yet.'),
      findsNothing,
    );
  });

  testWidgets('closes with the Close button', (tester) async {
    await _pumpDialog(
      tester,
      messages: [
        {'id': 'm1', 'content': 'First pinned note', 'is_pinned': true},
      ],
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationPinnedMessagesDialog), findsNothing);
  });
}
