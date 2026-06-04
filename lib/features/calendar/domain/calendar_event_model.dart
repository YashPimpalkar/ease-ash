import 'package:isar/isar.dart';

part 'calendar_event_model.g.dart';

@collection
class CalendarEvent {
  Id id = Isar.autoIncrement;

  late String title;

  String? description;

  @Index()
  late DateTime startTime;

  @Index()
  late DateTime endTime;

  @Index()
  late String category; // 'meeting', 'birthday', 'gym', 'task', etc.

  late String colorHex; // e.g. '#FF7F50'

  late bool isAllDay;

  late String recurrence; // 'none', 'daily', 'weekly', 'yearly'

  late bool isSynced;

  CalendarEvent({
    this.id = Isar.autoIncrement,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.colorHex,
    this.isAllDay = false,
    this.recurrence = 'none',
    this.isSynced = false,
  });
}
