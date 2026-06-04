import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../database/database_service.dart';
import '../database/secure_storage_service.dart';

import '../../features/tasks/domain/task_model.dart';
import '../../features/calendar/domain/calendar_event_model.dart';
import '../../features/budget/domain/transaction_model.dart';
import '../../features/fitness/domain/workout_model.dart';
import '../../features/journal/domain/diary_model.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return SyncService(dbService, secureStorage);
});

class SyncService {
  final DatabaseService _db;
  final SecureStorageService _secureStorage;

  SyncService(this._db, this._secureStorage);

  /// Run full bidirectional synchronization between local Isar and MongoDB
  Future<bool> syncAll() async {
    final mongoUri = await _secureStorage.getMongoDbUri();
    if (mongoUri == null || mongoUri.isEmpty) {
      print('Sync Service: MongoDB URI not configured.');
      return false;
    }

    mongo.Db? db;
    try {
      print('Sync Service: Connecting to remote MongoDB...');
      db = await mongo.Db.create(mongoUri);
      await db.open();
      print('Sync Service: Connected successfully!');

      // Synchronize each collection
      await _syncTasks(db);
      await _syncCalendarEvents(db);
      await _syncTransactions(db);
      await _syncGymWorkouts(db);
      await _syncDiaryEntries(db);

      print('Sync Service: Sync completed successfully!');
      return true;
    } catch (e) {
      print('Sync Service: Sync failed with error: $e');
      return false;
    } finally {
      if (db != null) {
        await db.close();
        print('Sync Service: Connection closed.');
      }
    }
  }

  // --- Collection Sync Logic ---

  Future<void> _syncTasks(mongo.Db db) async {
    final coll = db.collection('tasks');

    // 1. Push local unsynced tasks
    final unsynced = await _db.tasks.filter().isSyncedEqualTo(false).findAll();
    if (unsynced.isNotEmpty) {
      print('Sync Service: Pushing ${unsynced.length} tasks to MongoDB.');
      for (final task in unsynced) {
        final doc = _taskToMap(task);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
      }
      // Mark as synced locally
      await _db.isar.writeTxn(() async {
        for (final task in unsynced) {
          task.isSynced = true;
          await _db.tasks.put(task);
        }
      });
    }

    // 2. Pull remote tasks
    final remoteDocs = await coll.find().toList();
    if (remoteDocs.isNotEmpty) {
      await _db.isar.writeTxn(() async {
        for (final doc in remoteDocs) {
          final task = _taskFromMap(doc);
          await _db.tasks.put(task);
        }
      });
    }
  }

  Future<void> _syncCalendarEvents(mongo.Db db) async {
    final coll = db.collection('calendar_events');

    // 1. Push local unsynced
    final unsynced = await _db.calendarEvents.filter().isSyncedEqualTo(false).findAll();
    if (unsynced.isNotEmpty) {
      print('Sync Service: Pushing ${unsynced.length} events to MongoDB.');
      for (final event in unsynced) {
        final doc = _eventToMap(event);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
      }
      await _db.isar.writeTxn(() async {
        for (final event in unsynced) {
          event.isSynced = true;
          await _db.calendarEvents.put(event);
        }
      });
    }

    // 2. Pull remote
    final remoteDocs = await coll.find().toList();
    if (remoteDocs.isNotEmpty) {
      await _db.isar.writeTxn(() async {
        for (final doc in remoteDocs) {
          final event = _eventFromMap(doc);
          await _db.calendarEvents.put(event);
        }
      });
    }
  }

  Future<void> _syncTransactions(mongo.Db db) async {
    final coll = db.collection('transactions');

    // 1. Push local unsynced
    final unsynced = await _db.transactions.filter().isSyncedEqualTo(false).findAll();
    if (unsynced.isNotEmpty) {
      print('Sync Service: Pushing ${unsynced.length} transactions to MongoDB.');
      for (final tx in unsynced) {
        final doc = _transactionToMap(tx);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
      }
      await _db.isar.writeTxn(() async {
        for (final tx in unsynced) {
          tx.isSynced = true;
          await _db.transactions.put(tx);
        }
      });
    }

    // 2. Pull remote
    final remoteDocs = await coll.find().toList();
    if (remoteDocs.isNotEmpty) {
      await _db.isar.writeTxn(() async {
        for (final doc in remoteDocs) {
          final tx = _transactionFromMap(doc);
          await _db.transactions.put(tx);
        }
      });
    }
  }

  Future<void> _syncGymWorkouts(mongo.Db db) async {
    final coll = db.collection('gym_workouts');

    // 1. Push local unsynced
    final unsynced = await _db.gymWorkouts.filter().isSyncedEqualTo(false).findAll();
    if (unsynced.isNotEmpty) {
      print('Sync Service: Pushing ${unsynced.length} workouts to MongoDB.');
      for (final workout in unsynced) {
        final doc = _workoutToMap(workout);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
      }
      await _db.isar.writeTxn(() async {
        for (final workout in unsynced) {
          workout.isSynced = true;
          await _db.gymWorkouts.put(workout);
        }
      });
    }

    // 2. Pull remote
    final remoteDocs = await coll.find().toList();
    if (remoteDocs.isNotEmpty) {
      await _db.isar.writeTxn(() async {
        for (final doc in remoteDocs) {
          final workout = _workoutFromMap(doc);
          await _db.gymWorkouts.put(workout);
        }
      });
    }
  }

  Future<void> _syncDiaryEntries(mongo.Db db) async {
    final coll = db.collection('diary_entries');

    // 1. Push local unsynced
    final unsynced = await _db.diaryEntries.filter().isSyncedEqualTo(false).findAll();
    if (unsynced.isNotEmpty) {
      print('Sync Service: Pushing ${unsynced.length} diary entries to MongoDB.');
      for (final entry in unsynced) {
        final doc = _diaryToMap(entry);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
      }
      await _db.isar.writeTxn(() async {
        for (final entry in unsynced) {
          entry.isSynced = true;
          await _db.diaryEntries.put(entry);
        }
      });
    }

    // 2. Pull remote
    final remoteDocs = await coll.find().toList();
    if (remoteDocs.isNotEmpty) {
      await _db.isar.writeTxn(() async {
        for (final doc in remoteDocs) {
          final entry = _diaryFromMap(doc);
          await _db.diaryEntries.put(entry);
        }
      });
    }
  }

  // --- Serialization Mappings ---

  Map<String, dynamic> _taskToMap(Task task) => {
        '_id': task.id,
        'title': task.title,
        'description': task.description,
        'dueDate': task.dueDate.toIso8601String(),
        'isCompleted': task.isCompleted,
        'priority': task.priority,
        'subtasks': task.subtasks,
        'subtaskCompleted': task.subtaskCompleted,
        'category': task.category,
        'createdAt': task.createdAt.toIso8601String(),
      };

  Task _taskFromMap(Map<String, dynamic> map) => Task(
        id: map['_id'] as int,
        title: map['title'] as String,
        description: map['description'] as String?,
        dueDate: DateTime.parse(map['dueDate'] as String),
        isCompleted: map['isCompleted'] as bool? ?? false,
        priority: map['priority'] as String? ?? 'medium',
        subtasks: List<String>.from(map['subtasks'] ?? []),
        subtaskCompleted: List<bool>.from(map['subtaskCompleted'] ?? []),
        category: map['category'] as String? ?? 'Personal',
        createdAt: DateTime.parse(map['createdAt'] as String),
        isSynced: true,
      );

  Map<String, dynamic> _eventToMap(CalendarEvent event) => {
        '_id': event.id,
        'title': event.title,
        'description': event.description,
        'startTime': event.startTime.toIso8601String(),
        'endTime': event.endTime.toIso8601String(),
        'category': event.category,
        'colorHex': event.colorHex,
        'isAllDay': event.isAllDay,
        'recurrence': event.recurrence,
      };

  CalendarEvent _eventFromMap(Map<String, dynamic> map) => CalendarEvent(
        id: map['_id'] as int,
        title: map['title'] as String,
        description: map['description'] as String?,
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: DateTime.parse(map['endTime'] as String),
        category: map['category'] as String? ?? 'meeting',
        colorHex: map['colorHex'] as String? ?? '#6C63FF',
        isAllDay: map['isAllDay'] as bool? ?? false,
        recurrence: map['recurrence'] as String? ?? 'none',
        isSynced: true,
      );

  Map<String, dynamic> _transactionToMap(Transaction tx) => {
        '_id': tx.id,
        'title': tx.title,
        'description': tx.description,
        'amount': tx.amount,
        'isExpense': tx.isExpense,
        'category': tx.category,
        'date': tx.date.toIso8601String(),
      };

  Transaction _transactionFromMap(Map<String, dynamic> map) => Transaction(
        id: map['_id'] as int,
        title: map['title'] as String,
        description: map['description'] as String?,
        amount: (map['amount'] as num).toDouble(),
        isExpense: map['isExpense'] as bool? ?? true,
        category: map['category'] as String? ?? 'Food',
        date: DateTime.parse(map['date'] as String),
        isSynced: true,
      );

  Map<String, dynamic> _diaryToMap(DiaryEntry entry) => {
        '_id': entry.id,
        'title': entry.title,
        'content': entry.content,
        'date': entry.date.toIso8601String(),
        'moodEmoji': entry.moodEmoji,
        'moodValue': entry.moodValue,
        'aiFeedback': entry.aiFeedback,
      };

  DiaryEntry _diaryFromMap(Map<String, dynamic> map) => DiaryEntry(
        id: map['_id'] as int,
        title: map['title'] as String,
        content: map['content'] as String,
        date: DateTime.parse(map['date'] as String),
        moodEmoji: map['moodEmoji'] as String? ?? '😊',
        moodValue: (map['moodValue'] as num? ?? 3.0).toDouble(),
        aiFeedback: map['aiFeedback'] as String?,
        isSynced: true,
      );

  Map<String, dynamic> _workoutToMap(GymWorkout workout) => {
        '_id': workout.id,
        'name': workout.name,
        'date': workout.date.toIso8601String(),
        'exercises': workout.exercises.map((e) => {
              'exerciseName': e.exerciseName,
              'sets': e.sets?.map((s) => {
                    'setNum': s.setNum,
                    'weight': s.weight,
                    'reps': s.reps,
                    'isCompleted': s.isCompleted,
                  }).toList(),
            }).toList(),
      };

  GymWorkout _workoutFromMap(Map<String, dynamic> map) => GymWorkout(
        id: map['_id'] as int,
        name: map['name'] as String,
        date: DateTime.parse(map['date'] as String),
        exercises: (map['exercises'] as List?)?.map((e) {
              final eMap = e as Map<String, dynamic>;
              return ExerciseLog(
                exerciseName: eMap['exerciseName'] as String?,
                sets: (eMap['sets'] as List?)?.map((s) {
                      final sMap = s as Map<String, dynamic>;
                      return WorkoutSet(
                        setNum: sMap['setNum'] as int?,
                        weight: (sMap['weight'] as num?)?.toDouble(),
                        reps: sMap['reps'] as int?,
                        isCompleted: sMap['isCompleted'] as bool? ?? false,
                      );
                    }).toList() ??
                    [],
              );
            }).toList() ??
            [],
        isSynced: true,
      );
}
