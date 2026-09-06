import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

// What a thread is called where a reader sees it, and the mark it is
// recognised by. The API answers who is in a thread; the words are this
// client's, because a support thread has nobody else in it until somebody
// answers it and still has a name before then.
extension ConversationLook on Conversation {
  String titleFor(int callerId) => switch (type) {
    ConversationType.support => 'Gostio support',
    ConversationType.direct || ConversationType.unknown => withWhom(callerId),
  };

  // What the thread is about, where it is about anything. An enquiry is opened
  // before there is a booking to name, so it says nothing rather than
  // inventing a subject.
  String? get about => switch (type) {
    ConversationType.support => 'Help with your account',
    _ => listingTitle,
  };

  IconData get mark => switch (type) {
    ConversationType.support => Icons.support_agent_rounded,
    _ when isAboutABooking => Icons.luggage_rounded,
    _ => Icons.chat_bubble_outline_rounded,
  };

  Tone get tone =>
      type == ConversationType.support ? Tone.informative : Tone.neutral;
}
