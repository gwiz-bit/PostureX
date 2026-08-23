/// Read-only exercise info shown to regular users (browse list, detail
/// screen, guide video lookup). Deliberately separate from the admin app's
/// `AdminExercise` — that one carries CRUD-only fields (`isActive`,
/// `exerciseType`) this feature has no business depending on.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.demoVideoUrl,
  });

  final int id;
  final String name;
  final String? description;
  final String? category;
  final String? difficulty;
  final String? demoVideoUrl;
}
