import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeStorage extends Fake implements SecureStorageService {
  final values = <String, String>{};
  Completer<void>? readGate;

  @override
  Future<String?> readData(String key) async {
    await readGate?.future;
    return values[key];
  }

  @override
  Future<void> writeData(String key, String value) async => values[key] = value;
}

void main() {
  late _FakeStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = _FakeStorage();
    if (locator.isRegistered<SecureStorageService>()) {
      locator.unregister<SecureStorageService>();
    }
    locator.registerSingleton<SecureStorageService>(storage);
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    locator.unregister<SecureStorageService>();
  });

  test('is off until turned on', () async {
    expect(container.read(reduceMotionProvider), isFalse);
    await pumpEventQueue();
    expect(container.read(reduceMotionProvider), isFalse);
  });

  test('remembers the setting across restarts', () async {
    container.read(reduceMotionProvider.notifier).set(true);
    await pumpEventQueue();
    expect(storage.values[ReduceMotionNotifier.storageKey], 'true');

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    restarted.read(reduceMotionProvider);
    await pumpEventQueue();
    expect(restarted.read(reduceMotionProvider), isTrue);
  });

  test('a slow restore does not undo a change made meanwhile', () async {
    storage.values[ReduceMotionNotifier.storageKey] = 'true';
    storage.readGate = Completer();
    container.read(reduceMotionProvider);

    container.read(reduceMotionProvider.notifier).set(false);
    storage.readGate!.complete();
    await pumpEventQueue();

    expect(container.read(reduceMotionProvider), isFalse);
  });
}
