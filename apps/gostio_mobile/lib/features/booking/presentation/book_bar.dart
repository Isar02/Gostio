import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/bottom_action_bar.dart';
import '../../listing/data/listing_detail.dart';
import 'book_stay_screen.dart';
import 'book_term_screen.dart';

// The way into a booking, drawn under whatever listing is open. It carries the
// price because the price is what the reader is agreeing to look at next, and
// it stays under the thumb rather than scrolling away with the description.
//
// A host is not offered their own listing. The server refuses that booking,
// and a button that has to be pressed to learn so is a button that lied.
class BookBar extends StatelessWidget {
  const BookBar(this.detail, {super.key});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final bool isOwn = context.watch<Session>().account?.id == detail.hostId;

    return BottomActionBar(
      label: isOwn ? 'Your listing' : AppNumbers.money(detail.price),
      detail: isOwn
          ? 'A host does not book their own listing.'
          : detail.priceUnit,
      action: FilledButton(
        onPressed: isOwn ? null : () => _open(context),
        child: const Text('Book'),
      ),
    );
  }

  void _open(BuildContext context) => unawaited(switch (detail) {
    StayDetail(:final Accommodation stay) => BookStayScreen.open(context, stay),
    ExperienceDetail(:final Experience experience) => BookTermScreen.open(
      context,
      experience,
    ),
  });
}
