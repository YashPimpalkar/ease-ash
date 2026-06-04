import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/calendar/domain/calendar_event_model.dart';
import '../../features/fitness/domain/workout_model.dart';
import '../../features/journal/domain/diary_model.dart';
import '../../features/settings/domain/ai_model_config.dart';
import '../../features/tasks/domain/task_model.dart';
import '../../features/budget/domain/transaction_model.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('DatabaseService has not been initialized. Call init() first.');
});

class DatabaseService {
  final Isar isar;

  DatabaseService(this.isar);

  static Future<DatabaseService> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final isarInstance = await Isar.open(
      [
        AiModelConfigSchema,
        CalendarEventSchema,
        DiaryEntrySchema,
        GymWorkoutSchema,
        TaskSchema,
        TransactionSchema,
      ],
      directory: dir.path,
    );

    final service = DatabaseService(isarInstance);
    await service._bootstrapDefaultModels();
    return service;
  }

  // Pre-populate default AI Models for the failover engine
  Future<void> _bootstrapDefaultModels() async {
    // Migration: Update decommissioned model name if it exists in the database
    final decommissioned = await isar.aiModelConfigs.filter().modelNameEqualTo('llama-3.1-70b-versatile').findAll();
    if (decommissioned.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final model in decommissioned) {
          model.modelName = 'llama-3.3-70b-versatile';
          model.displayName = 'Llama 3.3 70B (Primary)';
          await isar.aiModelConfigs.put(model);
        }
      });
    }

    final count = await isar.aiModelConfigs.count();
    if (count == 0) {
      final defaultModels = [
        AiModelConfig(
          modelName: 'llama-3.3-70b-versatile',
          displayName: 'Llama 3.3 70B (Primary)',
          priority: 1,
        ),
        AiModelConfig(
          modelName: 'llama-3.3-70b-specdec',
          displayName: 'Llama 3.3 70B (Secondary)',
          priority: 2,
        ),
        AiModelConfig(
          modelName: 'llama3-70b-8192',
          displayName: 'Llama 3 70B (Tertiary)',
          priority: 3,
        ),
        AiModelConfig(
          modelName: 'llama-3.1-8b-instant',
          displayName: 'Llama 3.1 8B (Fast Backup)',
          priority: 4,
        ),
        AiModelConfig(
          modelName: 'gemma2-9b-it',
          displayName: 'Gemma 2 9B (Backup)',
          priority: 5,
        ),
      ];

      await isar.writeTxn(() async {
        await isar.aiModelConfigs.putAll(defaultModels);
      });
    }
  }

  // Helper getters for collections
  IsarCollection<AiModelConfig> get aiModelConfigs => isar.aiModelConfigs;
  IsarCollection<CalendarEvent> get calendarEvents => isar.calendarEvents;
  IsarCollection<DiaryEntry> get diaryEntries => isar.diaryEntrys;
  IsarCollection<GymWorkout> get gymWorkouts => isar.gymWorkouts;
  IsarCollection<Task> get tasks => isar.tasks;
  IsarCollection<Transaction> get transactions => isar.transactions;
}

final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.isar.transactions.where().sortByDateDesc().watch(fireImmediately: true);
});
