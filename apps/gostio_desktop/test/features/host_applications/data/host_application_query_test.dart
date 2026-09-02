import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application_query.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application_status.dart';

void main() {
  test('a filter nobody set is left out of the request', () {
    expect(const HostApplicationQuery().toParameters(), isEmpty);
    expect(const HostApplicationQuery().isEmpty, isTrue);
  });

  // The API binds its own enumeration from the name it answers with, so the
  // word on the chip is the word the filter sends back.
  test('a standing goes out under the API word for it', () {
    expect(
      const HostApplicationQuery(status: HostApplicationStatus.pending)
          .toParameters(),
      <String, dynamic>{'status': 'Pending'},
    );
  });

  test('two queries built the same way are the same query', () {
    expect(
      const HostApplicationQuery(status: HostApplicationStatus.approved),
      const HostApplicationQuery(status: HostApplicationStatus.approved),
    );
    expect(
      const HostApplicationQuery(status: HostApplicationStatus.approved),
      isNot(const HostApplicationQuery()),
    );
  });
}
