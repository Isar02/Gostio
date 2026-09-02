import 'package:json_annotation/json_annotation.dart';

import 'host_application_status.dart';

part 'host_application.g.dart';

@JsonSerializable(createToJson: false)
class HostApplication {
  const HostApplication({
    required this.id,
    required this.userId,
    required this.username,
    required this.applicantName,
    required this.status,
    required this.submittedAt,
    this.reviewedByUserId,
    this.reviewedByName,
    this.reviewedAt,
    this.decisionReason,
  });

  factory HostApplication.fromJson(Map<String, dynamic> json) =>
      _$HostApplicationFromJson(json);

  final int id;
  final int userId;
  final String username;
  final String applicantName;
  final String status;
  final DateTime submittedAt;

  // The three an answered request carries, and the reason a rejection always
  // does.
  final int? reviewedByUserId;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? decisionReason;

  HostApplicationStatus? get standing => HostApplicationStatus.forName(status);

  bool get isAnswered => reviewedAt != null;
}
