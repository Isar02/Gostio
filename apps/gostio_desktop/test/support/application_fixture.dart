import 'package:gostio_desktop/features/host_applications/data/host_application.dart';

// A request still waiting for an answer, which is the shape most of these
// tests read. What a test is about it names itself.
HostApplication application({
  int id = 5,
  String status = 'Pending',
  String? reviewedByName,
  DateTime? reviewedAt,
  String? decisionReason,
}) => HostApplication(
  id: id,
  userId: 21,
  username: 'ana.k',
  applicantName: 'Ana Kovač',
  status: status,
  submittedAt: DateTime.utc(2026, 8, 20, 9, 30),
  reviewedByUserId: reviewedByName == null ? null : 1,
  reviewedByName: reviewedByName,
  reviewedAt: reviewedAt,
  decisionReason: decisionReason,
);
