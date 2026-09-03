import 'package:json_annotation/json_annotation.dart';

enum ConversationType {
  @JsonValue(_direct)
  direct(_direct, 'Direct'),
  @JsonValue(_support)
  support(_support, 'Support'),
  // A type this build has not caught up with is still a thread to read.
  unknown('', 'Thread');

  const ConversationType(this.wireName, this.label);

  static const String _direct = 'Direct';
  static const String _support = 'Support';

  final String wireName;
  final String label;

  static const List<ConversationType> asked = <ConversationType>[
    direct,
    support,
  ];
}
