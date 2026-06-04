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

    // Migration: If no Gemini models exist in the database, bootstrap the default Gemini models
    final hasGemini = await isar.aiModelConfigs.filter().modelNameStartsWith('gemini-').count() > 0;
    if (!hasGemini && count > 0) {
      await isar.writeTxn(() async {
        // Shift priorities of all existing models by +3
        final existingModels = await isar.aiModelConfigs.where().findAll();
        for (final model in existingModels) {
          model.priority += 3;
          await isar.aiModelConfigs.put(model);
        }

        // Insert default Gemini models
        final geminiModels = [
          AiModelConfig(
            modelName: 'gemini-2.5-flash',
            displayName: 'Gemini 2.5 Flash (Primary)',
            priority: 1,
          ),
          AiModelConfig(
            modelName: 'gemini-2.5-pro',
            displayName: 'Gemini 2.5 Pro (Secondary)',
            priority: 2,
          ),
          AiModelConfig(
            modelName: 'gemini-1.5-flash',
            displayName: 'Gemini 1.5 Flash (Tertiary)',
            priority: 3,
          ),
        ];
        await isar.aiModelConfigs.putAll(geminiModels);
      });
    }

    final newCount = await isar.aiModelConfigs.count();
    if (newCount == 0) {
      final defaultModels = [
        AiModelConfig(
          modelName: 'gemini-2.5-flash',
          displayName: 'Gemini 2.5 Flash (Primary)',
          priority: 1,
        ),
        AiModelConfig(
          modelName: 'gemini-2.5-pro',
          displayName: 'Gemini 2.5 Pro (Secondary)',
          priority: 2,
        ),
        AiModelConfig(
          modelName: 'gemini-1.5-flash',
          displayName: 'Gemini 1.5 Flash (Tertiary)',
          priority: 3,
        ),
        AiModelConfig(
          modelName: 'llama-3.3-70b-versatile',
          displayName: 'Llama 3.3 70B',
          priority: 4,
        ),
        AiModelConfig(
          modelName: 'llama-3.3-70b-specdec',
          displayName: 'Llama 3.3 70B SpecDec',
          priority: 5,
        ),
        AiModelConfig(
          modelName: 'llama-3.1-8b-instant',
          displayName: 'Llama 3.1 8B (Fast Backup)',
          priority: 6,
        ),
        AiModelConfig(
          modelName: 'gemma2-9b-it',
          displayName: 'Gemma 2 9B (Backup)',
          priority: 7,
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
