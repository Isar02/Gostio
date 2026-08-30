import 'package:flutter/material.dart';

// Every place the content region can stand. The eight reference tables are
// sections like any other: what makes them a group is the navigation, not them.
enum AppSection {
  overview('Overview', Icons.space_dashboard_outlined),
  accommodations('Accommodations', Icons.apartment_outlined),
  experiences('Experiences', Icons.hiking_outlined),
  reservations('Reservations', Icons.event_available_outlined),
  users('Users', Icons.people_outline),
  hostApplications('Host applications', Icons.verified_user_outlined),
  reviews('Reviews', Icons.star_outline),
  news('News', Icons.article_outlined),
  reports('Reports', Icons.insert_chart_outlined),
  messages('Messages', Icons.forum_outlined),
  profile('Profile', Icons.person_outline),
  countries('Countries', Icons.public_outlined),
  cities('Cities', Icons.location_city_outlined),
  accommodationTypes('Accommodation types', Icons.home_work_outlined),
  accommodationCategories('Accommodation categories', Icons.category_outlined),
  experienceCategories('Experience categories', Icons.local_activity_outlined),
  amenities('Amenities', Icons.checklist_outlined),
  roles('Roles', Icons.badge_outlined),
  reservationStatuses('Reservation statuses', Icons.flag_outlined);

  const AppSection(this.label, this.icon);

  final String label;
  final IconData icon;
}
