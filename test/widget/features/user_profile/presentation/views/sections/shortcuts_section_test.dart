import 'package:zedu/core/core.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:zedu/core/window/global_hotkey.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

class _MockWindowManager extends Mock implements WindowManager {}

class _MockStorage extends Mock implements SecureStorageService {}

class _FakeRegistrar implements HotkeyRegistrar {
  final List<HotKey> registered = [];

  @override
  Future<void> register(
    HotKey hotKey, {
    required void Function() onPressed,
  }) async => registered.add(hotKey);

  @override
  Future<void> unregister(HotKey hotKey) async =>
      registered.removeWhere((k) => k.identifier == hotKey.identifier);
}

void main() {
  late _FakeRegistrar registrar;
  late GlobalHotkeyController controller;

  final ctrlShiftSpace = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
  );

  setUp(() async {
    final storage = _MockStorage();
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    when(() => storage.writeData(any(), any())).thenAnswer((_) async {});
    registrar = _FakeRegistrar();
    controller = GlobalHotkeyController(
      window: _MockWindowManager(),
      storage: storage,
      registrar: registrar,
      defaultHotkey: ctrlShiftSpace,
    );
    await controller.start();
  });

  Future<void> pump(WidgetTester tester, GlobalHotkeyController? c) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [globalHotkeyProvider.overrideWithValue(c)],
        child: buildTestMaterialApp(
          const Scaffold(
            body: SingleChildScrollView(child: ShortcutsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the show/hide shortcut with Change and Reset', (
    tester,
  ) async {
    await pump(tester, controller);

    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Show or hide Zedu'), findsOneWidget);
    expect(find.byType(HotKeyVirtualView), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Reset to default'), findsOneWidget);
  });

  testWidgets(
    'Change opens the recorder with Save disabled until a key is pressed',
    (tester) async {
      await pump(tester, controller);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Change shortcut'), findsOneWidget);
      expect(find.byType(HotKeyRecorder), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(save.onPressed, isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Change shortcut'), findsNothing);
    },
  );

  testWidgets('Reset to default re-registers the default shortcut', (
    tester,
  ) async {
    await controller.change(
      HotKey(key: PhysicalKeyboardKey.keyZ, modifiers: [HotKeyModifier.alt]),
    );
    await pump(tester, controller);

    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();

    expect(registrar.registered, hasLength(1));
    expect(registrar.registered.single.key, PhysicalKeyboardKey.space);
    expect(find.text('Shortcut updated.'), findsOneWidget);
    // Let the success toast time out.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('without a controller it explains shortcuts are unavailable', (
    tester,
  ) async {
    await pump(tester, null);

    expect(
      find.text('Global shortcuts are not available on this device.'),
      findsOneWidget,
    );
    expect(find.text('Change'), findsNothing);
  });
}
