import 'package:gostio_core/gostio_core.dart';

// A review that was changed says when it was changed rather than when it was
// first left: the words on the screen are the later ones. The card in a list
// and the review opened on its own both say it this way.
String reviewDateLabel(Review review) => review.wasEdited
    ? 'Edited ${AppDates.date(review.modifiedAt!)}'
    : AppDates.date(review.createdAt);
