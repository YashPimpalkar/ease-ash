import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/workout_model.dart';
import 'workout_active_screen.dart';
import 'package:isar/isar.dart';

class GymScreen extends ConsumerStatefulWidget {
  const GymScreen({super.key});

  @override
  ConsumerState<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends ConsumerState<GymScreen> {
  List<GymWorkout> _pastWorkouts = [];
  bool _isLoading = true;

  // Custom Workout Templates
  List<Map<String, dynamic>> _templates = [
    {
      'name': 'Push Day',
      'subtitle': 'Chest, Shoulders & Triceps',
      'exercises': ['Bench Press', 'Overhead Press', 'Lateral Raises', 'Tricep Pushdowns'],
    },
    {
      'name': 'Pull Day',
      'subtitle': 'Back & Biceps',
      'exercises': ['Lat Pulldowns', 'Barbell Rows', 'Bicep Curls', 'Face Pulls'],
    },
    {
      'name': 'Legs Day',
      'subtitle': 'Quadriceps, Hamstrings & Calves',
      'exercises': ['Squats', 'Leg Press', 'Leg Curls', 'Calf Raises'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPastWorkouts();
  }

  Future<void> _loadPastWorkouts() async {
    final db = ref.read(databaseServiceProvider);
    final workouts = await db.isar.gymWorkouts.where().sortByDateDesc().findAll();
    setState(() {
      _pastWorkouts = workouts;
      _isLoading = false;
    });
  }

  Future<void> _deleteWorkout(int id) async {
    final db = ref.read(databaseServiceProvider);
    await db.isar.writeTxn(() async {
      await db.isar.gymWorkouts.delete(id);
    });
    _loadPastWorkouts();
  }

  void _startWorkout(String name, List<String> exercises) async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutActiveScreen(
          templateName: name,
          defaultExercises: exercises,
        ),
      ),
    );

    if (success == true) {
      _loadPastWorkouts();
    }
  }

  void _showAddTemplateDialog() {
    final nameController = TextEditingController();
    final exercisesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131326),
          title: const Text('Add Workout Template', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Template Name (e.g. Upper Body)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: exercisesController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Exercises (comma separated)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () {
                if (nameController.text.isNotEmpty && exercisesController.text.isNotEmpty) {
                  final exList = exercisesController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  
                  setState(() {
                    _templates.add({
                      'name': nameController.text.trim(),
                      'subtitle': 'Custom Workout Template',
                      'exercises': exList,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Tracker'),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E6FF)))
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Text(
                      'Workout Templates',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ..._templates.map((temp) {
                      final List<String> exList = List<String>.from(temp['exercises']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AppTheme.glassCardDecoration(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      temp['name'],
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    Text(
                                      temp['subtitle'],
                                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${exList.length} Exercises: ${exList.join(', ')}',
                                      style: const TextStyle(color: Colors.white30, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E676),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _startWorkout(temp['name'], exList),
                                child: const Text('Start'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    Text(
                      'Workout History',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    _pastWorkouts.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AppTheme.glassCardDecoration(),
                            child: const Center(
                              child: Text(
                                'No logged workouts yet. Time to hit the weights!',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                          )
                        : Column(
                            children: _pastWorkouts.map((workout) {
                              return Dismissible(
                                key: Key(workout.id.toString()),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (dir) => _deleteWorkout(workout.id),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: AppTheme.glassCardDecoration(),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    iconColor: Colors.white,
                                    collapsedIconColor: Colors.white60,
                                    title: Text(
                                      workout.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    subtitle: Text(
                                      '${workout.date.day}/${workout.date.month}/${workout.date.year} • '
                                      '${workout.exercises.length} Exercises',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16.0, right: 16, bottom: 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: workout.exercises.map((ex) {
                                            final setsStr = ex.sets?.map((s) {
                                                  return '${s.weight}kg x ${s.reps}';
                                                }).join(', ') ??
                                                '';

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      ex.exerciseName ?? '',
                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      setsStr,
                                                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                                                      textAlign: TextAlign.right,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E676),
        onPressed: _showAddTemplateDialog,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
