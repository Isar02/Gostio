import 'package:json_annotation/json_annotation.dart';

part 'lookup_item.g.dart';

// A city answers more than an id and a name; the rest is ignored here, and
// the screen that manages cities takes it.
@JsonSerializable(createToJson: false)
class LookupItem {
  const LookupItem({required this.id, required this.name});

  factory LookupItem.fromJson(Map<String, dynamic> json) =>
      _$LookupItemFromJson(json);

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is LookupItem && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
