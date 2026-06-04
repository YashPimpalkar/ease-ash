import 'package:isar/isar.dart';

part 'task_model.g.dart';

@collection
class Task {
  Id id = Isar.autoIncrement;

  late String title;
  
  String? description;

  @Index()
  late DateTime dueDate;

  @Index()
  late bool isCompleted;

  @Index()
  late String priority; // 'low', 'medium', 'high'

  List<String> subtasks = [];
  
  List<bool> subtaskCompleted = [];

  @Index()
  late String category; // e.g. 'Personal', 'Work', 'Gym'

  late DateTime createdAt;

  late bool isSynced;

  Task({
    this.id = Isar.autoIncrement,
    required this.title,
    this.description,
    required this.dueDate,
    this.isCompleted = false,
    required this.priority,
    this.subtasks = const [],
    this.subtaskCompleted = const [],
    required this.category,
    required this.createdAt,
    this.isSynced = false,
  });
}
