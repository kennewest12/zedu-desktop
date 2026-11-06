import 'dart:convert';
import 'dart:io' show Platform;

import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:zedu/core/core.dart';

const _hotkeyStorageKey = 'global_show_hide_hotkey';

/// Registers system-wide hotkeys. The app uses [HotkeyManagerRegistrar];
/// tests pass a fake.
abstract interface class HotkeyRegistrar {
  Future<void> register(HotKey hotKey, {required void Function() onPressed});
  Future<void> unregister(HotKey hotKey);
}

class HotkeyManagerRegistrar implements HotkeyRegistrar {
  const HotkeyManagerRegistrar();

  @override
  Future<void> register(HotKey hotKey, {required void Function() onPressed}) =>
      hotKeyManager.register(hotKey, keyDownHandler: (_) => onPressed());

  @override
  Future<void> unregister(HotKey hotKey) => hotKeyManager.unregister(hotKey);
}

/// Ctrl+Shift+Space, or Cmd+Shift+Space on macOS.
HotKey defaultShowHideHotkey({bool? isMacOS}) => HotKey(
  key: PhysicalKeyboardKey.space,
  modifiers: [
    (isMacOS ?? Platform.isMacOS)
        ? HotKeyModifier.meta
        : HotKeyModifier.control,
    HotKeyModifier.shift,
  ],
  scope: HotKeyScope.system,
);

/// The system-wide shortcut that shows or hides the Zedu window from any app,
/// and lets the user change it. The shortcut is saved on this computer.
class GlobalHotkeyController {
  GlobalHotkeyController({
    required WindowManager window,
    required SecureStorageService storage,
    HotkeyRegistrar registrar = const HotkeyManagerRegistrar(),
    HotKey? defaultHotkey,
  }) : _window = window,
       _storage = storage,
       _registrar = registrar,
       _default = defaultHotkey ?? defaultShowHideHotkey();

  static const _tag = 'GlobalHotkey';

  final WindowManager _window;
  final SecureStorageService _storage;
  final HotkeyRegistrar _registrar;
  final HotKey _default;

  HotKey? _current;

  /// The shortcut in use, or the default before [start] runs.
  HotKey get current => _current ?? _default;

  HotKey get defaultHotkey => _default;

  /// Registers the saved shortcut, or the default when none is saved.
  Future<void> start() async {
    final saved = await _load();
    final hotKey = saved ?? _default;
    try {
      await _registrar.register(hotKey, onPressed: toggleWindow);
      _current = hotKey;
    } catch (error) {
      // Another app may already own the combination; the app still works.
      AppLogger.w('Could not register ${hotKey.debugName} - $error', tag: _tag);
    }
  }

  /// Switches to [next]. Returns an error message, or null when it took
  /// effect; on failure the previous shortcut stays registered.
  Future<String?> change(HotKey next) async {
    if (next.modifiers == null || next.modifiers!.isEmpty) {
      return 'Use at least one modifier key, such as Ctrl, Alt or Shift.';
    }
    final hotKey = HotKey(
      key: next.key,
      modifiers: next.modifiers,
      scope: HotKeyScope.system,
    );
    final previous = _current;
    if (previous != null) await _registrar.unregister(previous);
    try {
      await _registrar.register(hotKey, onPressed: toggleWindow);
    } catch (error) {
      AppLogger.w('Could not register ${hotKey.debugName} - $error', tag: _tag);
      if (previous != null) {
        await _registrar.register(previous, onPressed: toggleWindow);
      }
      return 'That shortcut is not available. Try another combination.';
    }
    _current = hotKey;
    try {
      await _storage.writeData(_hotkeyStorageKey, jsonEncode(hotKey.toJson()));
    } catch (error) {
      AppLogger.w('Could not save the shortcut - $error', tag: _tag);
    }
    return null;
  }

  /// Goes back to [defaultHotkey].
  Future<String?> reset() => change(_default);

  /// Hides Zedu when it is in front, otherwise shows and focuses it.
  Future<void> toggleWindow() async {
    final visible = await _window.isVisible();
    final focused = await _window.isFocused();
    if (visible && focused) {
      await _window.hide();
    } else {
      await _window.show();
      await _window.focus();
    }
  }

  Future<HotKey?> _load() async {
    try {
      final raw = await _storage.readData(_hotkeyStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final saved = HotKey.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return HotKey(
        key: saved.key,
        modifiers: saved.modifiers,
        scope: HotKeyScope.system,
      );
    } catch (error) {
      AppLogger.w('Ignoring an unreadable saved shortcut - $error', tag: _tag);
      return null;
    }
  }
}

/// The controller registered at startup on desktop, or null where there is
/// none (tests, or a platform without global shortcuts).
final globalHotkeyProvider = Provider<GlobalHotkeyController?>(
  (ref) => locator.isRegistered<GlobalHotkeyController>()
      ? locator<GlobalHotkeyController>()
      : null,
);

/// Starts the show/hide shortcut at launch and makes it available to Settings.
/// A failure here never stops the app from opening.
Future<void> startGlobalHotkey() async {
  try {
    // Clears registrations left over from a hot restart in development.
    await hotKeyManager.unregisterAll();
    final controller = GlobalHotkeyController(
      window: windowManager,
      storage: locator<SecureStorageService>(),
    );
    locator.registerSingleton<GlobalHotkeyController>(controller);
    await controller.start();
  } catch (error) {
    AppLogger.w('Global shortcut unavailable - $error', tag: 'GlobalHotkey');
  }
}
