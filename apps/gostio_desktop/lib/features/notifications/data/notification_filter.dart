// The one search parameter this list takes. The API keys it as a nullable
// boolean, so All is the absence of the filter rather than a third value.
enum NotificationFilter {
  all('All', null),
  unread('Unread', false),
  read('Read', true);

  const NotificationFilter(this.label, this.isRead);

  final String label;
  final bool? isRead;
}
