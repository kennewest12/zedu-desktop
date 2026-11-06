import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/core/window/global_hotkey.dart';

class _MockWindowManager extends Mock implements WindowManager {}

class _MockStorage extends Mock implements SecureStorageService {}

/// Records registrations like the OS would, and can refuse a combination.
class _FakeRegistrar implements HotkeyRegistrar {
  final Map<String, void Function()> registered = {};
  final Set<String> refused = {};

  static String label(HotKey k) =>
      '${(k.modifiers ?? []).map((m) => m.name).join('+')}+${k.physicalKey.usbHidUsage}';

  @override
  Future<void> register(
    HotKey hotKey, {
    required void Function() onPressed,
  }) async {
    if (refused.contains(label(hotKey))) throw Exception('taken');
    registered[label(hotKey)] = onPressed;
  }

  @override
  Future<void> unregister(HotKey hotKey) async {
    registered.remove(label(hotKey));
  }

  void press(HotKey k) => registered[label(k)]!();
}

const _key = 'global_show_hide_hotkey';

void main() {
  late _MockWindowManager window;
  late _MockStorage storage;
  late _FakeRegistrar registrar;
  String? saved;

  final ctrlShiftSpace = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
  );
  final altZ = HotKey(
    key: PhysicalKeyboardKey.keyZ,
    modifiers: [HotKeyModifier.alt],
  );

  GlobalHotkeyController controller() => GlobalHotkeyController(
    window: window,
    storage: storage,
    registrar: registrar,
    defaultHotkey: ctrlShiftSpace,
  );

  setUp(() {
    window = _MockWindowManager();
    storage = _MockStorage();
    registrar = _FakeRegistrar();
    saved = null;
    when(() => storage.readData(_key)).thenAnswer((_) async => saved);
    when(() => storage.writeData(_key, any())).thenAnswer((inv) async {
      saved = inv.positionalArguments[1] as String;
    });
    when(() => window.show()).thenAnswer((_) async {});
    when(() => window.focus()).thenAnswer((_) async {});
    when(() => window.hide()).thenAnswer((_) async {});
  });

  void windowState({required bool visible, required bool focused}) {
    when(() => window.isVisible()).thenAnswer((_) async => visible);
    when(() => window.isFocused()).thenAnswer((_) async => focused);
  }

  test('start registers the default shortcut when none is saved', () async {
    final c = controller();
    await c.start();

    expect(registrar.registered.keys, [_FakeRegistrar.label(ctrlShiftSpace)]);
    expect(
      _FakeRegistrar.label(c.current),
      _FakeRegistrar.label(ctrlShiftSpace),
    );
  });

  test('start registers the saved shortcut instead of the default', () async {
    saved = jsonEncode(altZ.toJson());
    final c = controller();
    await c.start();

    expect(registrar.registered.keys, [_FakeRegistrar.label(altZ)]);
  });

  test('an unreadable saved value falls back to the default', () async {
    saved = 'not json';
    await controller().start();

    expect(registrar.registered.keys, [_FakeRegistrar.label(ctrlShiftSpace)]);
  });

  test(
    'pressing the shortcut while another app is in front shows Zedu',
    () async {
      windowState(visible: true, focused: false);
      final c = controller();
      await c.start();

      registrar.press(ctrlShiftSpace);
      await pumpEventQueue();

      verify(() => window.show()).called(1);
      verify(() => window.focus()).called(1);
      verifyNever(() => window.hide());
    },
  );

  test('pressing the shortcut while Zedu is hidden shows it', () async {
    windowState(visible: false, focused: false);
    await controller().toggleWindow();

    verify(() => window.show()).called(1);
    verify(() => window.focus()).called(1);
  });

  test('pressing the shortcut while Zedu is in front hides it', () async {
    windowState(visible: true, focused: true);
    await controller().toggleWindow();

    verify(() => window.hide()).called(1);
    verifyNever(() => window.show());
  });

  test('changing the shortcut swaps the registration and saves it', () async {
    final c = controller();
    await c.start();

    final error = await c.change(altZ);

    expect(error, isNull);
    expect(registrar.registered.keys, [_FakeRegistrar.label(altZ)]);
    expect(saved, isNotNull);
    final restored = HotKey.fromJson(
      jsonDecode(saved!) as Map<String, dynamic>,
    );
    expect(_FakeRegistrar.label(restored), _FakeRegistrar.label(altZ));
  });

  test(
    'a shortcut without a modifier is refused and nothing changes',
    () async {
      final c = controller();
      await c.start();

      final error = await c.change(HotKey(key: PhysicalKeyboardKey.keyZ));

      expect(error, isNotNull);
      expect(registrar.registered.keys, [_FakeRegistrar.label(ctrlShiftSpace)]);
      expect(saved, isNull);
    },
  );

  test(
    'a combination the system refuses keeps the previous shortcut',
    () async {
      final c = controller();
      await c.start();
      registrar.refused.add(_FakeRegistrar.label(altZ));

      final error = await c.change(altZ);

      expect(error, isNotNull);
      expect(registrar.registered.keys, [_FakeRegistrar.label(ctrlShiftSpace)]);
      expect(
        _FakeRegistrar.label(c.current),
        _FakeRegistrar.label(ctrlShiftSpace),
      );
    },
  );

  test('reset goes back to the default shortcut', () async {
    saved = jsonEncode(altZ.toJson());
    final c = controller();
    await c.start();

    await c.reset();

    expect(registrar.registered.keys, [_FakeRegistrar.label(ctrlShiftSpace)]);
  });

  test('the default uses Cmd on macOS and Ctrl elsewhere', () {
    expect(
      defaultShowHideHotkey(isMacOS: true).modifiers,
      contains(HotKeyModifier.meta),
    );
    expect(
      defaultShowHideHotkey(isMacOS: false).modifiers,
      contains(HotKeyModifier.control),
    );
  });
}
