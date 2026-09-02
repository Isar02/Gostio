import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application_status.dart';

void main() {
  test('the API words name the standings this client knows', () {
    expect(
      HostApplicationStatus.forName('Pending'),
      HostApplicationStatus.pending,
    );
    expect(
      HostApplicationStatus.forName('Approved'),
      HostApplicationStatus.approved,
    );
    expect(
      HostApplicationStatus.forName('Rejected'),
      HostApplicationStatus.rejected,
    );
    expect(HostApplicationStatus.forName('Withdrawn'), isNull);
  });

  // The server answers a request once and refuses the second answer, so a
  // request that already has one offers neither move.
  test('only a request nobody has answered is still open', () {
    expect(HostApplicationStatus.pending.canBeDecided, isTrue);
    expect(HostApplicationStatus.approved.canBeDecided, isFalse);
    expect(HostApplicationStatus.rejected.canBeDecided, isFalse);
  });
}
