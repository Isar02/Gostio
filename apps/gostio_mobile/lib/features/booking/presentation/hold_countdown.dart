import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/widgets/app_notice.dart';

// How long the booking keeps its place. A hold nobody mentioned is a booking
// that quietly disappears, so it is counted down on the screen rather than
// left as a date the reader has to subtract from.
class HoldCountdown extends StatefulWidget {
  const HoldCountdown(this.expiresAt, {super.key});

  final DateTime expiresAt;

  @override
  State<HoldCountdown> createState() => _HoldCountdownState();
}

class _HoldCountdownState extends State<HoldCountdown> {
  Timer? _timer;
  late Duration _left = _remaining();

  @override
  void initState() {
    super.initState();

    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left == Duration.zero) {
      return const AppNotice('The hold on this booking ran out.');
    }

    return AppNotice(
      'Held for $_spoken. It is released if it has not been paid for by '
      '${AppDates.dateTime(widget.expiresAt)}.',
      tone: Tone.attention,
    );
  }

  // A day of hold is read in hours and the last of it in minutes, so the clock
  // behind it runs no faster than the sentence it changes.
  Duration get _step => _left.inHours >= 1
      ? const Duration(minutes: 1)
      : const Duration(seconds: 1);

  String get _spoken => _left.inMinutes >= 1
      ? AppDurations.inWords(_left.inMinutes)
      : 'less than a minute';

  Duration _remaining() {
    final Duration left = widget.expiresAt.toUtc().difference(
      DateTime.now().toUtc(),
    );

    return left.isNegative ? Duration.zero : left;
  }

  void _schedule() {
    if (_left == Duration.zero) {
      return;
    }

    _timer = Timer(_step, () {
      setState(() => _left = _remaining());
      _schedule();
    });
  }
}
