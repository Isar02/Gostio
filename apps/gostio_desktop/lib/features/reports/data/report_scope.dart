// Which of the two report families the client asks. A host's scope is built on
// the server from the token, so all this choice carries is the route.
enum ReportScope {
  platform('/reports', 'Platform', 'platform'),
  mine('/reports/mine', 'My listings', 'mine');

  const ReportScope(this.root, this.label, this.slug);

  final String root;

  final String label;

  final String slug;
}
