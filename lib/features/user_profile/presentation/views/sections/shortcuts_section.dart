import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/core/window/global_hotkey.dart';
import 'package:zedu/features/features.dart';

/// Settings > Keyboard shortcuts: the system-wide shortcut that shows or
/// hides Zedu, and a way to change it.
class ShortcutsSection extends ConsumerStatefulWidget {
  const ShortcutsSection({super.key});

  @override
  ConsumerState<ShortcutsSection> createState() => _ShortcutsSectionState();
}

class _ShortcutsSectionState extends ConsumerState<ShortcutsSection> {
  bool _busy = false;
  String? _error;

  Future<void> _apply(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) {
      AppToastService.show(
        context,
        type: AppToastType.success,
        message: 'Shortcut updated.',
      );
    }
  }

  Future<void> _change(GlobalHotkeyController hotkeys) async {
    final recorded = await showDialog<HotKey>(
      context: context,
      builder: (_) => _RecordShortcutDialog(initial: hotkeys.current),
    );
    if (recorded == null || !mounted) return;
    await _apply(() => hotkeys.change(recorded));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hotkeys = ref.watch(globalHotkeyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Keyboard shortcuts',
          subtitle:
              'Shortcuts that work on this computer, even from other apps.',
        ),
        const SizedBox(height: 28),
        ProfileCard(
          child: hotkeys == null
              ? Text(
                  'Global shortcuts are not available on this device.',
                  style: TextStyle(color: colors.textSecondary),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show or hide Zedu',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Press it from any app to bring Zedu to the front. '
                            'Press it again while Zedu is in front to hide it.',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            label: 'Current shortcut',
                            child: HotKeyVirtualView(hotKey: hotkeys.current),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(color: colors.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _busy ? null : () => _change(hotkeys),
                          child: const Text('Change'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => _apply(hotkeys.reset),
                          child: const Text('Reset to default'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecordShortcutDialog extends StatefulWidget {
  const _RecordShortcutDialog({required this.initial});

  final HotKey initial;

  @override
  State<_RecordShortcutDialog> createState() => _RecordShortcutDialogState();
}

class _RecordShortcutDialogState extends State<_RecordShortcutDialog> {
  HotKey? _recorded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: const Text('Change shortcut'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Press the new key combination, including Ctrl, Alt, Shift or Cmd.',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          HotKeyRecorder(
            initalHotKey: widget.initial,
            onHotKeyRecorded: (hotKey) => setState(() => _recorded = hotKey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _recorded == null
              ? null
              : () => Navigator.of(context).pop(_recorded),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
