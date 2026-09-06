import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';

// What is written and the button that sends it. The field grows to a few lines
// and no further: a thread is read above it, and a box that filled the screen
// would take the conversation away to write one line of it.
//
// The controller belongs to the screen, because what is half typed is also
// what Back has to ask about before it takes it.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    required this.body,
    required this.isSending,
    required this.onSend,
    this.refusal,
    super.key,
  });

  // Where the count starts being drawn. Below it the figure is noise; above it
  // the reader is near enough the ceiling to want to know.
  static const int countedFrom = Validators.messageBodyMaximum ~/ 2;

  final TextEditingController body;
  final bool isSending;
  final String? refusal;
  final Future<bool> Function(String body) onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final FocusNode _writing = FocusNode();

  String? _refusal;

  @override
  void dispose() {
    _writing.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.body,
                builder: (BuildContext context, TextEditingValue written, _) =>
                    TextField(
                      controller: widget.body,
                      focusNode: _writing,
                      enabled: !widget.isSending,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Write a message',
                        errorText: _refusal ?? widget.refusal,
                        counterText: _counter(written.text),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _SendButton(isSending: widget.isSending, onPressed: _send),
          ],
        ),
      ),
    );
  }

  String _counter(String written) {
    final int length = written.trim().length;

    return length < MessageComposer.countedFrom
        ? ''
        : '$length of ${Validators.messageBodyMaximum}';
  }

  // The rule the server holds is checked before anything is sent, so a message
  // that could not be written is refused here rather than by a round trip.
  Future<void> _send() async {
    if (widget.isSending) {
      return;
    }

    final String body = widget.body.text.trim();
    final String? refusal = Validators.messageBody(body);

    if (refusal != null) {
      setState(() => _refusal = refusal);

      return;
    }

    setState(() => _refusal = null);

    if (await widget.onSend(body) && mounted) {
      widget.body.clear();
      _writing.requestFocus();
    }
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onPressed});

  final bool isSending;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.touchTarget,
      height: AppSizes.touchTarget,
      child: IconButton.filled(
        onPressed: isSending ? null : onPressed,
        tooltip: 'Send',
        icon: isSending
            ? const SizedBox(
                width: AppSizes.iconSmall,
                height: AppSizes.iconSmall,
                child: CircularProgressIndicator(
                  strokeWidth: AppSizes.stroke,
                  color: AppColors.surface,
                ),
              )
            : const Icon(Icons.send_rounded, size: AppSizes.icon),
      ),
    );
  }
}
