import 'package:isar/isar.dart';

part 'diary_model.g.dart';

@collection
class DiaryEntry {
  Id id = Isar.autoIncrement;

  late String title;

  late String content;

  @Index()
  late DateTime date;

  late String moodEmoji; // e.g. '😊', '😢', '🔥'

  @Index()
  late double moodValue; // Numeric representation for mood trend visualization (e.g. 1.0 to 5.0)

  String? aiFeedback;

  late bool isSynced;

  DiaryEntry({
    this.id = Isar.autoIncrement,
    required this.title,
    required this.content,
    required this.date,
    required this.moodEmoji,
    required this.moodValue,
    this.aiFeedback,
    this.isSynced = false,
  });
}
