enum ExerciseStatus { published, draft, hidden }

extension ExerciseStatusX on ExerciseStatus {
  String get label {
    switch (this) {
      case ExerciseStatus.published:
        return 'Published';
      case ExerciseStatus.draft:
        return 'Draft';
      case ExerciseStatus.hidden:
        return 'Hidden';
    }
  }
}

class Exercise {
  final String name;
  final String detail;
  ExerciseStatus status;

  Exercise({
    required this.name,
    required this.detail,
    this.status = ExerciseStatus.draft,
  });
}
