import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Pinned messages" for a DM: the conversation's pinned messages, oldest
/// first. It loads the older pages too, so a message pinned long ago is still
/// found, and says so plainly when nothing is pinned.
class ConversationPinnedMessagesDialog extends StatefulWidget {
  const ConversationPinnedMessagesDialog({
    super.key,
    required this.title,
    required this.history,
  });

  final String title;
  final ChatHistoryNotifier history;

  @override
  State<ConversationPinnedMessagesDialog> createState() =>
      _ConversationPinnedMessagesDialogState();
}

class _ConversationPinnedMessagesDialogState
    extends State<ConversationPinnedMessagesDialog> {
  bool _loadingOlder = true;

  @override
  void initState() {
    super.initState();
    widget.history.addListener(_onHistory);
    widget.history.loadAll().whenComplete(() {
      if (mounted) setState(() => _loadingOlder = false);
    });
  }

  @override
  void dispose() {
    widget.history.removeListener(_onHistory);
    super.dispose();
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pinned = widget.history.messages
        .where(
          (message) =>
              message['is_pinned'] == true || message['pinned'] == true,
        )
        .toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pinned.isEmpty && !_loadingOlder)
              const Text('No pinned messages in this conversation yet.')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pinned.length,
                  itemBuilder: (context, index) {
                    final message = pinned[index];
                    return ListTile(
                      leading: const Icon(Icons.push_pin_outlined),
                      title: Text(message['content']?.toString() ?? ''),
                    );
                  },
                ),
              ),
            if (_loadingOlder)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading older messages…',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
