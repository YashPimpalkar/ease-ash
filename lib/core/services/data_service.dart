import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../database/database_service.dart';
import '../database/secure_storage_service.dart';
import '../../features/auth/presentation/auth_provider.dart';

import '../../features/tasks/domain/task_model.dart';
import '../../features/calendar/domain/calendar_event_model.dart';
import '../../features/budget/domain/transaction_model.dart';
import '../../features/fitness/domain/workout_model.dart';
import '../../features/journal/domain/diary_model.dart';

final dataServiceProvider = Provider<DataService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final auth = ref.watch(authProvider);
  final email = auth.email ?? '';
  return DataService(db, storage, email);
});

class DataService {
  final DatabaseService _db;
  final SecureStorageService _storage;
  final String _userEmail;

  DataService(this._db, this._storage, this._userEmail);

  Future<mongo.Db?> _getMongoDb() async {
    final uri = await _storage.getMongoDbUri() ?? SecureStorageService.defaultMongoUri;
    if (uri.isEmpty) return null;
    try {
      final db = await mongo.Db.create(uri);
      await db.open();
      return db;
    } catch (e) {
      print('DataService: MongoDB connection failed: $e');
      return null;
    }
  }

  // --- Tasks Operations ---

  Future<void> saveTask(Task task) async {
    // Ensure task has user email
    if (task.userEmail == null || task.userEmail!.isEmpty) {
      task.userEmail = _userEmail;
    }

    // 1. Write to Isar first to obtain unique auto-increment ID
    await _db.isar.writeTxn(() async {
      await _db.tasks.put(task);
    });

    // 2. Attempt to save to MongoDB
    bool success = false;
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('tasks');
        final doc = _taskToMap(task);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
        success = true;
      }
    } catch (e) {
      print('DataService: Failed to save task online: $e');
    } finally {
      if (db != null) await db.close();
    }

    // 3. Update sync state locally in Isar
    if (success) {
      task.isSynced = true;
      await _db.isar.writeTxn(() async {
        await _db.tasks.put(task);
      });
    }
  }

  Future<void> deleteTask(int id) async {
    // 1. Attempt to delete online
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('tasks');
        await coll.deleteOne({'_id': id});
      }
    } catch (e) {
      print('DataService: Failed to delete task online: $e');
    } finally {
      if (db != null) await db.close();
    }

    // 2. Delete locally
    await _db.isar.writeTxn(() async {
      await _db.tasks.delete(id);
    });
  }

  // --- Calendar Event Operations ---

  Future<void> saveCalendarEvent(CalendarEvent event) async {
    if (event.userEmail == null || event.userEmail!.isEmpty) {
      event.userEmail = _userEmail;
    }

    await _db.isar.writeTxn(() async {
      await _db.calendarEvents.put(event);
    });

    bool success = false;
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('calendar_events');
        final doc = _eventToMap(event);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
        success = true;
      }
    } catch (e) {
      print('DataService: Failed to save event online: $e');
    } finally {
      if (db != null) await db.close();
    }

    if (success) {
      event.isSynced = true;
      await _db.isar.writeTxn(() async {
        await _db.calendarEvents.put(event);
      });
    }
  }

  Future<void> deleteCalendarEvent(int id) async {
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('calendar_events');
        await coll.deleteOne({'_id': id});
      }
    } catch (e) {
      print('DataService: Failed to delete event online: $e');
    } finally {
      if (db != null) await db.close();
    }

    await _db.isar.writeTxn(() async {
      await _db.calendarEvents.delete(id);
    });
  }

  // --- Budget Transaction Operations ---

  Future<void> saveTransaction(Transaction tx) async {
    if (tx.userEmail == null || tx.userEmail!.isEmpty) {
      tx.userEmail = _userEmail;
    }

    await _db.isar.writeTxn(() async {
      await _db.transactions.put(tx);
    });

    bool success = false;
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('transactions');
        final doc = _transactionToMap(tx);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
        success = true;
      }
    } catch (e) {
      print('DataService: Failed to save transaction online: $e');
    } finally {
      if (db != null) await db.close();
    }

    if (success) {
      tx.isSynced = true;
      await _db.isar.writeTxn(() async {
        await _db.transactions.put(tx);
      });
    }
  }

  Future<void> deleteTransaction(int id) async {
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('transactions');
        await coll.deleteOne({'_id': id});
      }
    } catch (e) {
      print('DataService: Failed to delete transaction online: $e');
    } finally {
      if (db != null) await db.close();
    }

    await _db.isar.writeTxn(() async {
      await _db.transactions.delete(id);
    });
  }

  // --- Gym Workout Operations ---

  Future<void> saveGymWorkout(GymWorkout workout) async {
    if (workout.userEmail == null || workout.userEmail!.isEmpty) {
      workout.userEmail = _userEmail;
    }

    await _db.isar.writeTxn(() async {
      await _db.gymWorkouts.put(workout);
    });

    bool success = false;
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('gym_workouts');
        final doc = _workoutToMap(workout);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
        success = true;
      }
    } catch (e) {
      print('DataService: Failed to save workout online: $e');
    } finally {
      if (db != null) await db.close();
    }

    if (success) {
      workout.isSynced = true;
      await _db.isar.writeTxn(() async {
        await _db.gymWorkouts.put(workout);
      });
    }
  }

  Future<void> deleteGymWorkout(int id) async {
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('gym_workouts');
        await coll.deleteOne({'_id': id});
      }
    } catch (e) {
      print('DataService: Failed to delete workout online: $e');
    } finally {
      if (db != null) await db.close();
    }

    await _db.isar.writeTxn(() async {
      await _db.gymWorkouts.delete(id);
    });
  }

  // --- Diary Entry Operations ---

  Future<void> saveDiaryEntry(DiaryEntry entry) async {
    if (entry.userEmail == null || entry.userEmail!.isEmpty) {
      entry.userEmail = _userEmail;
    }

    await _db.isar.writeTxn(() async {
      await _db.isar.diaryEntrys.put(entry);
    });

    bool success = false;
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('diary_entries');
        final doc = _diaryToMap(entry);
        await coll.replaceOne({'_id': doc['_id']}, doc, upsert: true);
        success = true;
      }
    } catch (e) {
      print('DataService: Failed to save diary online: $e');
    } finally {
      if (db != null) await db.close();
    }

    if (success) {
      entry.isSynced = true;
      await _db.isar.writeTxn(() async {
        await _db.isar.diaryEntrys.put(entry);
      });
    }
  }

  Future<void> deleteDiaryEntry(int id) async {
    mongo.Db? db;
    try {
      db = await _getMongoDb();
      if (db != null) {
        final coll = db.collection('diary_entries');
        await coll.deleteOne({'_id': id});
      }
    } catch (e) {
      print('DataService: Failed to delete diary online: $e');
    } finally {
      if (db != null) await db.close();
    }

    await _db.isar.writeTxn(() async {
      await _db.isar.diaryEntrys.delete(id);
    });
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
        'userEmail': task.userEmail ?? _userEmail,
      };

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
        'userEmail': event.userEmail ?? _userEmail,
      };

  Map<String, dynamic> _transactionToMap(Transaction tx) => {
        '_id': tx.id,
        'title': tx.title,
        'description': tx.description,
        'amount': tx.amount,
        'isExpense': tx.isExpense,
        'category': tx.category,
        'date': tx.date.toIso8601String(),
        'userEmail': tx.userEmail ?? _userEmail,
        'smsRefNo': tx.smsRefNo,
      };

  Map<String, dynamic> _diaryToMap(DiaryEntry entry) => {
        '_id': entry.id,
        'title': entry.title,
        'content': entry.content,
        'date': entry.date.toIso8601String(),
        'moodEmoji': entry.moodEmoji,
        'moodValue': entry.moodValue,
        'aiFeedback': entry.aiFeedback,
        'userEmail': entry.userEmail ?? _userEmail,
      };

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
        'userEmail': workout.userEmail ?? _userEmail,
      };
}
