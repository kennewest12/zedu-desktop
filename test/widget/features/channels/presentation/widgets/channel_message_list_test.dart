import '../../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

class FakeChatHistoryNotifier extends ChangeNotifier
    implements ChatHistoryNotifier {
  FakeChatHistoryNotifier(this.channelId);

  @override
  final String channelId;

  @override
  List<Map<String, dynamic>> messages = [];

  @override
  String get currentUserName => 'Test User';

  @override
  String? get currentUserAvatarUrl => null;

  String? retriedMessageId;

  @override
  Future<void> retryMessage(String messageId) async {
    retriedMessageId = messageId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockChannelRepository repository;
  late FakeChatHistoryNotifier fakeChatHistory;

  setUp(() {
    repository = MockChannelRepository();
    fakeChatHistory = FakeChatHistoryNotifier('ch-1');
  });

  Future<void> pumpList(
    WidgetTester tester,
    Result<List<ChannelMessage>> r, {
    FakeChatHistoryNotifier? chatNotifier,
    int unreadCount = 0,
  }) {
    when(
      () => repository.fetchChannelMessages('ch-1'),
    ).thenAnswer((_) async => r);
    return tester
        .pumpWidget(
          ProviderScope(
            overrides: [
              channelRepositoryProvider.overrideWithValue(repository),
              chatHistoryProvider.overrideWith(
                (ref, channelId) => chatNotifier ?? fakeChatHistory,
              ),
            ],
            retry: (_, _) => null,
            child: buildTestMaterialApp(
              Scaffold(
                body: ChannelMessageList(
                  channelId: 'ch-1',
                  empty: const Text('Welcome to #general'),
                  unreadCount: unreadCount,
                ),
              ),
            ),
          ),
        )
        .then((_) => tester.pumpAndSettle());
  }

  testWidgets('shows the messages, newest at the bottom', (tester) async {
    await pumpList(
      tester,
      const Success([
        ChannelMessage(senderName: 'gold', text: 'newest'),
        ChannelMessage(senderName: 'Ada', text: 'oldest'),
      ]),
    );

    expect(find.text('Welcome to #general'), findsNothing);
    expect(
      tester.getTopLeft(find.text('oldest')).dy,
      lessThan(tester.getTopLeft(find.text('newest')).dy),
    );
  });

  testWidgets('opens a URL in a message when it is tapped', (tester) async {
    final opened = <Uri>[];
    final original = messageLinkLauncher;
    messageLinkLauncher = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => messageLinkLauncher = original);

    await pumpList(
      tester,
      const Success([
        ChannelMessage(senderName: 'Ada', text: 'https://example.com/channel'),
      ]),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(SelectableText)) + const Offset(20, 8),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(opened, [Uri.parse('https://example.com/channel')]);
  });

  testWidgets('shows the welcome screen when empty', (tester) async {
    await pumpList(tester, const Success(<ChannelMessage>[]));

    expect(find.text('Welcome to #general'), findsOneWidget);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    await pumpList(tester, const Failure(ApiFailure(message: 'boom')));

    expect(find.text("Couldn't load messages. Retry"), findsOneWidget);
  });

  testWidgets(
    'renders placeholder initial for empty senderName without crashing',
    (tester) async {
      await pumpList(
        tester,
        const Success([ChannelMessage(senderName: '', text: 'empty sender')]),
      );

      expect(find.text('?'), findsOneWidget);
      expect(find.text('empty sender'), findsOneWidget);
    },
  );

  testWidgets(
    'shows sending indicator for optimistic pending channel message (#2571)',
    (tester) async {
      fakeChatHistory.messages = [
        {
          'id': 'temp-1',
          'content': 'Sending channel message',
          'channel_id': 'ch-1',
          'status': 'sending',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      await pumpList(tester, const Success(<ChannelMessage>[]));

      expect(find.text('Sending channel message'), findsOneWidget);
      expect(find.text('Sending...'), findsOneWidget);
    },
  );

  testWidgets(
    'shows failed indicator and invokes retryMessage on tap (#2571)',
    (tester) async {
      fakeChatHistory.messages = [
        {
          'id': 'failed-msg-1',
          'content': 'Failed channel message',
          'channel_id': 'ch-1',
          'status': 'failed',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      await pumpList(tester, const Success(<ChannelMessage>[]));

      expect(find.text('Failed channel message'), findsOneWidget);
      expect(find.text('Failed – Tap to retry'), findsOneWidget);

      await tester.tap(find.text('Failed – Tap to retry'));
      expect(fakeChatHistory.retriedMessageId, 'failed-msg-1');
    },
  );

  group('thread replies (#2682)', () {
    testWidgets('renders reply count indicator badge when replyCount > 0', (
      tester,
    ) async {
      await pumpList(
        tester,
        Success([
          ChannelMessage(
            id: 'm-thread',
            senderName: 'Ada',
            text: 'Thread starting post',
            replyCount: 4,
            replyAvatars: const ['https://cdn.zedu.chat/avatar1.png'],
            lastReplyAt: DateTime(2026, 11, 5, 14, 30),
          ),
        ]),
      );

      expect(find.text('4 replies'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('thread-reply-indicator-m-thread')),
        findsOneWidget,
      );
    });

    testWidgets(
      'does not show reply count indicator badge when replyCount is 0',
      (tester) async {
        await pumpList(
          tester,
          const Success([
            ChannelMessage(
              id: 'm-no-thread',
              senderName: 'Ada',
              text: 'Message without thread',
              replyCount: 0,
            ),
          ]),
        );

        expect(find.textContaining('replies'), findsNothing);
        expect(
          find.byKey(const ValueKey('thread-reply-indicator-m-no-thread')),
          findsNothing,
        );
      },
    );

    testWidgets('Reply in thread action triggers thread opening', (
      tester,
    ) async {
      await pumpList(
        tester,
        const Success([
          ChannelMessage(
            id: 'm-reply',
            senderName: 'Ada',
            text: 'Please reply here',
            replyCount: 0,
          ),
        ]),
      );

      expect(find.text('Reply in thread'), findsOneWidget);
      await tester.tap(find.text('Reply in thread'));
      await tester.pumpAndSettle();

      expect(find.byType(ThreadPanel), findsOneWidget);
      expect(find.text('Thread'), findsOneWidget);
    });

    testWidgets('tapping reply count indicator badge opens ThreadPanel', (
      tester,
    ) async {
      await pumpList(
        tester,
        const Success([
          ChannelMessage(
            id: 'm-badge',
            senderName: 'Grace',
            text: 'Parent topic message',
            replyCount: 2,
          ),
        ]),
      );

      await tester.tap(find.text('2 replies'));
      await tester.pumpAndSettle();

      expect(find.byType(ThreadPanel), findsOneWidget);
      expect(find.byTooltip('Close thread'), findsOneWidget);

      await tester.tap(find.byTooltip('Close thread'));
      await tester.pumpAndSettle();

      expect(find.byType(ThreadPanel), findsNothing);
    });
  });

  group('unread messages', () {
    // Newest first, as the server sends them: 'msg N' is the newest.
    Success<List<ChannelMessage>> messages(int n) => Success([
      for (var i = n; i >= 1; i--)
        ChannelMessage(senderName: 'Ada', text: 'msg $i'),
    ]);

    const divider = 'New messages';
    final jump = find.byKey(const ValueKey('jump-to-first-unread'));

    testWidgets('marks where the unread messages start', (tester) async {
      await pumpList(tester, messages(5), unreadCount: 3);

      // Unread: msg 5, msg 4, msg 3. The divider sits between msg 2 and msg 3.
      expect(find.text(divider), findsOneWidget);
      final dividerY = tester.getTopLeft(find.text(divider)).dy;
      expect(tester.getTopLeft(find.text('msg 2')).dy, lessThan(dividerY));
      expect(dividerY, lessThan(tester.getTopLeft(find.text('msg 3')).dy));
    });

    testWidgets('shows no divider when nothing was unread', (tester) async {
      await pumpList(tester, messages(5));

      expect(find.text(divider), findsNothing);
      expect(jump, findsNothing);
    });

    testWidgets('a few unread messages get the divider but no jump button', (
      tester,
    ) async {
      await pumpList(tester, messages(30), unreadCount: 3);

      expect(find.text(divider), findsOneWidget);
      expect(jump, findsNothing);
    });

    testWidgets('many unread messages offer a jump to the first one', (
      tester,
    ) async {
      await pumpList(tester, messages(40), unreadCount: 25);

      // The first unread message is msg 16, far above what is on screen.
      expect(jump, findsOneWidget);
      expect(find.text('Jump to first unread · 25 new'), findsOneWidget);
      final viewportHeight = tester.view.physicalSize.height;
      expect(
        find.text('msg 16'),
        findsNothing,
        reason: 'the first unread message is far above what is on screen',
      );

      await tester.tap(jump);
      await tester.pumpAndSettle();

      final y = tester.getTopLeft(find.text('msg 16')).dy;
      expect(y, inInclusiveRange(0, viewportHeight));
      expect(jump, findsNothing);
      expect(find.text(divider), findsOneWidget);
    });

    testWidgets('more unread than loaded puts the divider at the very top', (
      tester,
    ) async {
      await pumpList(tester, messages(5), unreadCount: 50);

      expect(find.text(divider), findsOneWidget);
      expect(jump, findsOneWidget);
      // Nothing is above the divider: it is above the oldest loaded message.
      final dividerY = tester.getTopLeft(find.text(divider)).dy;
      expect(dividerY, lessThan(tester.getTopLeft(find.text('msg 1')).dy));
    });
  });
}
