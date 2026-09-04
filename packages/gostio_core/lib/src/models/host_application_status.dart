// The standings the API answers with, by its own words for them, so nothing
// here renames one and the filter sends back what it was given.
enum HostApplicationStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const HostApplicationStatus(this.label);

  final String label;

  static HostApplicationStatus? forName(String name) {
    for (final HostApplicationStatus standing in values) {
      if (standing.label == name) {
        return standing;
      }
    }

    return null;
  }

  // A request is answered once. A standing this client does not know is left
  // alone: the server is the authority, and guessing on its behalf is what
  // this avoids.
  bool get canBeDecided => this == pending;
}
