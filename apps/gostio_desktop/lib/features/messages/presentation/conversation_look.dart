import '../../../core/theme/tone.dart';
import '../data/conversation_type.dart';

extension ConversationLook on ConversationType {
  Tone get tone => switch (this) {
    ConversationType.support => Tone.informative,
    ConversationType.direct || ConversationType.unknown => Tone.neutral,
  };
}
