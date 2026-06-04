import 'package:isar/isar.dart';

part 'workout_model.g.dart';

@embedded
class WorkoutSet {
  int? setNum;
  double? weight;
  int? reps;
  bool? isCompleted;

  WorkoutSet({
    this.setNum,
    this.weight,
    this.reps,
    this.isCompleted = false,
  });
}

@embedded
class ExerciseLog {
  String? exerciseName;
  List<WorkoutSet>? sets;

  ExerciseLog({
    this.exerciseName,
    this.sets,
  });
}

@collection
class GymWorkout {
  Id id = Isar.autoIncrement;

  late String name; // e.g., 'Push Day', 'Pull Day'

  @Index()
  late DateTime date;

  List<ExerciseLog> exercises = [];

  late bool isSynced;

  @Index()
  String? userEmail;

  GymWorkout({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.date,
    this.exercises = const [],
    this.isSynced = false,
    this.userEmail,
  });
}
