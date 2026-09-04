import 'package:gostio_core/gostio_core.dart';

extension ConversationLook on ConversationType {
  Tone get tone => switch (this) {
    ConversationType.support => Tone.informative,
    ConversationType.direct || ConversationType.unknown => Tone.neutral,
  };
}
