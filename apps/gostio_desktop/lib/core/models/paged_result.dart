import 'package:json_annotation/json_annotation.dart';

part 'paged_result.g.dart';

// The envelope every list endpoint answers with. TotalPages is not read: the
// footer derives it, and one arithmetic is easier to trust than two.
@JsonSerializable(createToJson: false, genericArgumentFactories: true)
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$PagedResultFromJson<T>(json, fromJsonT);

  static const int defaultPageSize = 20;

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
}
