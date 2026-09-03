import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/validation/validators.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    required this.hint,
    required this.isSending,
    required this.refusal,
    required this.onSend,
    super.key,
  });

  static const int countedFrom = Validators.messageBodyMaximum ~/ 2;

  final String hint;
  final bool isSending;

  final String? refusal;

  final Future<bool> Function(String body) onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _body = TextEditingController();
  final FocusNode _writing = FocusNode();

  String? _refusal;
  int _written = 0;

  @override
  void initState() {
    super.initState();
    _body.addListener(_counted);
  }

  @override
  void dispose() {
    _body
      ..removeListener(_counted)
      ..dispose();
    _writing.dispose();

    super.dispose();
  }

  void _counted() {
    final int written = _body.text.trim().length;
    if (written != _written) {
      setState(() => _written = written);
    }
  }

  Future<void> _send() async {
    if (widget.isSending) {
      return;
    }

    final String body = _body.text.trim();
    final String? refusal = Validators.messageBody(body);

    if (refusal != null) {
      setState(() => _refusal = refusal);

      return;
    }

    setState(() => _refusal = null);

    if (await widget.onSend(body) && mounted) {
      _body.clear();
      _writing.requestFocus();
    }
  }

  // The key is caught above the field so the newline is never written and
  // then taken back.
  KeyEventResult _typed(FocusNode node, KeyEvent event) {
    final bool sends =
        event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed;

    if (!sends) {
      return KeyEventResult.ignored;
    }

    _send();

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Focus(
                  canRequestFocus: false,
                  onKeyEvent: _typed,
                  child: TextField(
                    controller: _body,
                    focusNode: _writing,
                    enabled: !widget.isSending,
                    minLines: 1,
                    maxLines: 5,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      errorText: _refusal ?? widget.refusal,
                      counterText: _written < MessageComposer.countedFrom
                          ? ''
                          : '$_written of ${Validators.messageBodyMaximum}',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                height: AppSizes.control,
                child: FilledButton.icon(
                  onPressed: widget.isSending ? null : _send,
                  icon: widget.isSending
                      ? const SizedBox(
                          width: AppSizes.iconSmall,
                          height: AppSizes.iconSmall,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSizes.stroke,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: AppSizes.icon),
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Text(
              'Enter sends. Shift and Enter write a line.',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}
