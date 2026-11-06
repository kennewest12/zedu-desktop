import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockChatHistory extends Mock implements ChatHistoryNotifier {}

class MockDraftStore extends Mock implements DmDraftStore {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

void main() {
  setUp(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  testWidgets('DM menu uses a white surface and opens the selected action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final history = MockChatHistory();
    when(() => history.messages).thenReturn([]);
    when(() => history.isLoading).thenReturn(false);
    when(() => history.hasMore).thenReturn(false);
    when(() => history.loadFailed).thenReturn(false);
    when(() => history.loadMoreFailed).thenReturn(false);
    when(() => history.historyCleared).thenReturn(false);
    when(() => history.isMyMessage(any())).thenReturn(false);
    final drafts = MockDraftStore();
    when(() => drafts.load(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          chatHistoryProvider('chat-1').overrideWith((ref) => history),
          dmDraftStoreProvider.overrideWith((ref) => drafts),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmChatArea(
              conversation: DmConversation(
                channelId: 'chat-1',
                username: 'Menu Tester',
                participantId: 'user-1',
                previewMessage: '',
                unreadCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();

    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Delete conversation'), findsOneWidget);
    final menuSurface = tester
        .widgetList<Material>(find.byType(Material))
        .where(
          (material) =>
              material.shape is RoundedRectangleBorder &&
              material.elevation == 8,
        );
    expect(menuSurface, hasLength(1));
    expect(menuSurface.single.color, AppPalette.light.onPrimary);
    expect(menuSurface.single.surfaceTintColor, Colors.transparent);
    expect(
      tester.widget<Text>(find.text('Delete conversation')).style?.color,
      AppPalette.light.error,
    );

    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('User ID: user-1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('DM menu opens Pinned messages dialog showing empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final history = MockChatHistory();
    when(() => history.messages).thenReturn([]);
    when(() => history.isLoading).thenReturn(false);
    when(() => history.hasMore).thenReturn(false);
    when(() => history.loadFailed).thenReturn(false);
    when(() => history.loadMoreFailed).thenReturn(false);
    when(() => history.historyCleared).thenReturn(false);
    when(() => history.isMyMessage(any())).thenReturn(false);
    final drafts = MockDraftStore();
    when(() => drafts.load(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          chatHistoryProvider('chat-1').overrideWith((ref) => history),
          dmDraftStoreProvider.overrideWith((ref) => drafts),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmChatArea(
              conversation: DmConversation(
                channelId: 'chat-1',
                username: 'Menu Tester',
                participantId: 'user-1',
                previewMessage: '',
                unreadCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();

    expect(find.text('Pinned messages'), findsOneWidget);
    await tester.tap(find.text('Pinned messages'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Pinned messages in Menu Tester'), findsOneWidget);
    expect(find.text('No pinned messages'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('DM menu opens Pinned messages dialog showing pinned messages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final history = MockChatHistory();
    when(() => history.messages).thenReturn([
      {
        'id': 'msg-1',
        'content': '<p>Important pinned announcement</p>',
        'is_pinned': true,
        'sender_name': 'Alice',
        'created_at': '2026-11-05T12:00:00Z',
      },
      {
        'id': 'msg-2',
        'content': '<p>Regular unpinned message</p>',
        'is_pinned': false,
        'sender_name': 'Bob',
        'created_at': '2026-11-05T12:05:00Z',
      },
    ]);
    when(() => history.isLoading).thenReturn(false);
    when(() => history.hasMore).thenReturn(false);
    when(() => history.loadFailed).thenReturn(false);
    when(() => history.loadMoreFailed).thenReturn(false);
    when(() => history.historyCleared).thenReturn(false);
    when(() => history.isMyMessage(any())).thenReturn(false);
    final drafts = MockDraftStore();
    when(() => drafts.load(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          chatHistoryProvider('chat-1').overrideWith((ref) => history),
          dmDraftStoreProvider.overrideWith((ref) => drafts),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmChatArea(
              conversation: DmConversation(
                channelId: 'chat-1',
                username: 'Menu Tester',
                participantId: 'user-1',
                previewMessage: '',
                unreadCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pinned messages'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Pinned messages in Menu Tester'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Important pinned announcement'), findsOneWidget);
    expect(find.text('Regular unpinned message'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
