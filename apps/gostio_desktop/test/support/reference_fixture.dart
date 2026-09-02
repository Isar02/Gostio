import 'package:gostio_desktop/features/reference/data/reference_row.dart';

ReferenceRow referenceRow(
  int id,
  String name, [
  Map<String, dynamic> details = const <String, dynamic>{},
]) => ReferenceRow.fromJson(<String, dynamic>{
  ReferenceKeys.id: id,
  ReferenceKeys.name: name,
  ...details,
});
