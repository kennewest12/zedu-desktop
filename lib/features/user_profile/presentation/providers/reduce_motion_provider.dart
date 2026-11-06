import 'dart:async';

import 'package:zedu/core/core.dart';

/// Whether Reduce motion is on. It is a preference about this computer's
/// display, so it is remembered here for every account rather than per user.
final reduceMotionProvider = NotifierProvider<ReduceMotionNotifier, bool>(
  ReduceMotionNotifier.new,
);

class ReduceMotionNotifier extends Notifier<bool> {
  static const storageKey = 'reduce_motion';
  static const _tag = 'ReduceMotion';

  /// Set once the person changes it, so a slow restore can't undo the change.
  bool _changed = false;

  @override
  bool build() {
    _restore();
    return false;
  }

  Future<void> _restore() async {
    if (!locator.isRegistered<SecureStorageService>()) return;
    try {
      final saved = await locator<SecureStorageService>().readData(storageKey);
      if (!ref.mounted || _changed) return;
      state = saved == 'true';
    } catch (error) {
      AppLogger.w('Could not read $storageKey - $error', tag: _tag);
    }
  }

  void set(bool value) {
    _changed = true;
    state = value;
    unawaited(_save(value));
  }

  Future<void> _save(bool value) async {
    if (!locator.isRegistered<SecureStorageService>()) return;
    try {
      await locator<SecureStorageService>().writeData(storageKey, '$value');
    } catch (error) {
      AppLogger.w('Could not save $storageKey - $error', tag: _tag);
    }
  }
}
