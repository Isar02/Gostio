import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../data/conversations_repository.dart';
import '../data/thread_subject.dart';
import 'thread_screen.dart';

// The way into a thread from wherever the reader is: a listing whose host they
// want to ask, a booking they want to ask about, or support. All three open the
// same screen, and the server answers the thread that already stands rather
// than refusing a second one — so this is one control with three subjects
// rather than three controls.
//
// The thread is pushed into the tab it was opened from, so the bar stays under
// it and closing it comes back to where the reader was.
class OpenThreadButton extends StatefulWidget {
  const OpenThreadButton({
    required this.subject,
    required this.label,
    this.icon = Icons.chat_bubble_outline_rounded,
    super.key,
  });

  final ThreadSubject subject;
  final String label;
  final IconData icon;

  @override
  State<OpenThreadButton> createState() => _OpenThreadButtonState();
}

class _OpenThreadButtonState extends State<OpenThreadButton> {
  bool _isOpening = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isOpening ? null : _open,
        icon: _isOpening
            ? const SizedBox(
                width: AppSizes.iconSmall,
                height: AppSizes.iconSmall,
                child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
              )
            : Icon(widget.icon, size: AppSizes.iconSmall),
        label: Text(widget.label),
      ),
    );
  }

  Future<void> _open() async {
    final int? callerId = context.read<Session>().account?.id;
    if (callerId == null) {
      return;
    }

    final ConversationsRepository conversations = context
        .read<ConversationsRepository>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // The route this button is on, rather than the navigator it was pushed
    // into: that navigator is the tab's and outlives the screen, so a thread
    // opened after the reader has left would land on whatever replaced it.
    final ModalRoute<Object?>? here = ModalRoute.of(context);

    setState(() => _isOpening = true);

    try {
      final Conversation thread = await conversations.open(widget.subject);

      if (here?.isActive ?? false) {
        await navigator.push(ThreadScreen.route(thread, callerId: callerId));
      }
    } on ApiException catch (refused) {
      if (here?.isActive ?? false) {
        messenger.showSnackBar(SnackBar(content: Text(refused.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }
}
