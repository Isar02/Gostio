import 'package:gostio_core/gostio_core.dart';

// An application the way the API answers one. The standing is what a test is
// about, so it is what a test names; everything else is a plausible row.
HostApplication hostApplication({
  int id = 71,
  int userId = 12,
  String username = 'emina.b',
  String applicantName = 'Emina Begić',
  String status = 'Pending',
  DateTime? submittedAt,
  int? reviewedByUserId,
  String? reviewedByName,
  DateTime? reviewedAt,
  String? decisionReason,
}) => HostApplication(
  id: id,
  userId: userId,
  username: username,
  applicantName: applicantName,
  status: status,
  submittedAt: submittedAt ?? DateTime.utc(2026, 8, 30, 9),
  reviewedByUserId: reviewedByUserId,
  reviewedByName: reviewedByName,
  reviewedAt: reviewedAt,
  decisionReason: decisionReason,
);

HostApplication turnedDown({
  String reason = 'The uploaded document was unreadable.',
}) => hostApplication(
  status: 'Rejected',
  reviewedByUserId: 3,
  reviewedByName: 'Nedim Alispahić',
  reviewedAt: DateTime.utc(2026, 9, 1, 14),
  decisionReason: reason,
);

HostApplication approved() => hostApplication(
  status: 'Approved',
  reviewedByUserId: 3,
  reviewedByName: 'Nedim Alispahić',
  reviewedAt: DateTime.utc(2026, 9, 1, 14),
);
