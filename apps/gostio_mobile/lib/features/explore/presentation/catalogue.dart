// The two catalogues the toggle above the results moves between. Each names
// what it counts and what to say when it answers with nothing, so the generic
// results view below it never has to ask which one it is drawing.
enum Catalogue {
  stays(
    label: 'Stays',
    noun: 'stays',
    hint: 'Search stays',
    emptyTitle: 'No stays match',
    emptyMessage:
        'Try a wider price, fewer amenities, or dates with more nights free.',
  ),
  experiences(
    label: 'Experiences',
    noun: 'experiences',
    hint: 'Search experiences',
    emptyTitle: 'No experiences match',
    emptyMessage: 'Try another city, a longer window of days, or fewer places.',
  );

  const Catalogue({
    required this.label,
    required this.noun,
    required this.hint,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String label;
  final String noun;
  final String hint;
  final String emptyTitle;
  final String emptyMessage;
}
