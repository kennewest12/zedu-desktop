import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

/// Leaving a conversation disposes its autoDispose [chatHistoryProvider]
/// while requests may still be in flight. When they finish, the notifier must
/// not read its ref or notify listeners (#2633).
void main() {
  late MockDmRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<ChatHistoryNotifier> subscription;

  final loaded = [
    {'id': 'm1', 'content': 'hello', 'user_id': 'u1', 'thread_id': 't1'},
  ];

  setUp(() {
    repository = MockDmRepository();
    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_SignedOutAuth.new),
        dmRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Opens the conversation and waits for its first page.
  Future<ChatHistoryNotifier> open() async {
    subscription = container.listen(chatHistoryProvider('ch-1'), (_, _) {});
    final notifier = subscription.read();
    await pumpEventQueue();
    return notifier;
  }

  /// Leaves the conversation: the autoDispose provider is disposed.
  Future<void> leave() async {
    subscription.close();
    await pumpEventQueue();
  }

  test('the first page finishing after leaving does nothing', () async {
    final page = Completer<List<Map<String, dynamic>>>();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) => page.future);

    subscription = container.listen(chatHistoryProvider('ch-1'), (_, _) {});
    final notifier = subscription.read();
    var notified = 0;
    notifier.addListener(() => notified++);
    await leave();

    page.complete(loaded);
    await pumpEventQueue();

    expect(notified, 0);
  });

  test('a send finishing after leaving does nothing', () async {
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => loaded);
    final sent = Completer<String>();
    when(
      () => repository.sendMessage(
        any(),
        any(),
        media: any(named: 'media'),
        mentions: any(named: 'mentions'),
        isChannel: any(named: 'isChannel'),
      ),
    ).thenAnswer((_) => sent.future);

    final notifier = await open();
    unawaited(notifier.sendMessage('hi'));
    await pumpEventQueue();
    await leave();

    sent.complete('t2');
    await pumpEventQueue();
  });

  test('a failed send after leaving does nothing', () async {
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => loaded);
    final sent = Completer<String>();
    when(
      () => repository.sendMessage(
        any(),
        any(),
        media: any(named: 'media'),
        mentions: any(named: 'mentions'),
        isChannel: any(named: 'isChannel'),
      ),
    ).thenAnswer((_) => sent.future);

    final notifier = await open();
    unawaited(notifier.sendMessage('hi'));
    await pumpEventQueue();
    await leave();

    sent.completeError(Exception('offline'));
    await pumpEventQueue();
  });

  test('older history arriving after leaving does nothing', () async {
    final pages = <Completer<List<Map<String, dynamic>>>>[];
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((invocation) {
      if (invocation.namedArguments[#page] == 1) {
        return Future.value(
          List.generate(
            DmRepository.pageSize,
            (i) => {'id': 'm$i', 'content': '$i', 'user_id': 'u1'},
          ),
        );
      }
      final completer = Completer<List<Map<String, dynamic>>>();
      pages.add(completer);
      return completer.future;
    });

    final notifier = await open();
    unawaited(notifier.loadMore());
    await pumpEventQueue();
    await leave();

    pages.single.complete([]);
    await pumpEventQueue();
  });

  test('a delete failing after leaving does nothing', () async {
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => loaded);
    final deleted = Completer<void>();
    when(
      () => repository.deleteMessage(
        threadId: any(named: 'threadId'),
        channelId: any(named: 'channelId'),
      ),
    ).thenAnswer((_) => deleted.future);

    final notifier = await open();
    unawaited(notifier.deleteMessage('m1'));
    await pumpEventQueue();
    await leave();

    deleted.completeError(Exception('offline'));
    await pumpEventQueue();
  });

  test('an edit failing after leaving does nothing', () async {
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => loaded);
    final edited = Completer<void>();
    when(
      () => repository.editMessage(
        any(),
        content: any(named: 'content'),
        threadId: any(named: 'threadId'),
      ),
    ).thenAnswer((_) => edited.future);

    final notifier = await open();
    unawaited(notifier.saveEdit('m1', 'changed'));
    await pumpEventQueue();
    await leave();

    edited.completeError(Exception('offline'));
    await pumpEventQueue();
  });
}
