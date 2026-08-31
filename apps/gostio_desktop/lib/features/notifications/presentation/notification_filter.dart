enum NotificationFilter {
  all('All', null),
  unread('Unread', false),
  read('Read', true);

  const NotificationFilter(this.label, this.isRead);

  final String label;
  final bool? isRead;
}
