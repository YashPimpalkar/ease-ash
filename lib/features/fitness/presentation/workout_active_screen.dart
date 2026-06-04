import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/workout_model.dart';

class WorkoutActiveScreen extends ConsumerStatefulWidget {
  final String templateName;
  final List<String> defaultExercises;

  const WorkoutActiveScreen({
    super.key,
    required this.templateName,
    required this.defaultExercises,
  });

  @override
  ConsumerState<WorkoutActiveScreen> createState() => _WorkoutActiveScreenState();
}

class _WorkoutActiveScreenState extends ConsumerState<WorkoutActiveScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _timeDisplay = '00:00';

  // GymWorkout log structure
  List<ExerciseLog> _exerciseLogs = [];

  // Rest Timer State
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isResting = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final minutes = _stopwatch.elapsed.inMinutes.toString().padLeft(2, '0');
          final seconds = (_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0');
          _timeDisplay = '$minutes:$seconds';
        });
      }
    });

    // Populate initial exercises and sets
    _exerciseLogs = widget.defaultExercises.map((name) {
      return ExerciseLog(
        exerciseName: name,
        sets: [
          WorkoutSet(setNum: 1, weight: 60.0, reps: 10, isCompleted: false),
          WorkoutSet(setNum: 2, weight: 60.0, reps: 10, isCompleted: false),
          WorkoutSet(setNum: 3, weight: 60.0, reps: 10, isCompleted: false),
        ],
      );
    }).toList();
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = 60; // 60 seconds rest
      _isResting = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_restSecondsRemaining > 1) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isResting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rest time over! Start your next set!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFF00E676),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _addSet(ExerciseLog log) {
    setState(() {
      final sets = log.sets ?? [];
      final nextNum = sets.length + 1;
      final lastWeight = sets.isNotEmpty ? sets.last.weight ?? 60.0 : 60.0;
      final lastReps = sets.isNotEmpty ? sets.last.reps ?? 10 : 10;
      
      sets.add(WorkoutSet(
        setNum: nextNum,
        weight: lastWeight,
        reps: lastReps,
        isCompleted: false,
      ));
      log.sets = sets;
    });
  }

  void _addCustomExercise() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131326),
          title: const Text('Add Exercise', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Exercise Name',
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _exerciseLogs.add(ExerciseLog(
                      exerciseName: controller.text.trim(),
                      sets: [WorkoutSet(setNum: 1, weight: 20.0, reps: 10, isCompleted: false)],
                    ));
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

  Future<void> _finishWorkout() async {
    final db = ref.read(databaseServiceProvider);
    
    // Create new GymWorkout record
    final workout = GymWorkout(
      name: widget.templateName,
      date: DateTime.now(),
      exercises: _exerciseLogs,
      isSynced: false,
    );

    await db.isar.writeTxn(() async {
      await db.isar.gymWorkouts.put(workout);
    });

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.templateName),
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Color(0xFF00E6FF), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _timeDisplay,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF00E6FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Active Rest Banner
              if (_isResting)
                Container(
                  width: double.infinity,
                  color: const Color(0xFF00E676).withAlpha(40),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hourglass_empty, color: Color(0xFF00E676), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'RESTING: ${_restSecondsRemaining}s',
                        style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          _restTimer?.cancel();
                          setState(() {
                            _isResting = false;
                          });
                        },
                        child: const Text('SKIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _exerciseLogs.length,
                  itemBuilder: (context, exIndex) {
                    final log = _exerciseLogs[exIndex];
                    final sets = log.sets ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                log.exerciseName ?? 'Exercise',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E6FF)),
                                onPressed: () => _addSet(log),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(flex: 1, child: Text('SET', style: TextStyle(color: Colors.white60, fontSize: 12))),
                              const Expanded(flex: 2, child: Text('WEIGHT (kg)', style: TextStyle(color: Colors.white60, fontSize: 12))),
                              const Expanded(flex: 2, child: Text('REPS', style: TextStyle(color: Colors.white60, fontSize: 12))),
                              const Expanded(flex: 1, child: Text('DONE', style: TextStyle(color: Colors.white60, fontSize: 12))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...sets.asMap().entries.map((setEntry) {
                            final setItem = setEntry.value;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${setItem.setNum}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: TextField(
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                                        ),
                                        controller: TextEditingController(text: '${setItem.weight}')
                                          ..selection = TextSelection.fromPosition(TextPosition(offset: '${setItem.weight}'.length)),
                                        onChanged: (val) {
                                          setItem.weight = double.tryParse(val) ?? 0.0;
                                        },
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                                        ),
                                        controller: TextEditingController(text: '${setItem.reps}')
                                          ..selection = TextSelection.fromPosition(TextPosition(offset: '${setItem.reps}'.length)),
                                        onChanged: (val) {
                                          setItem.reps = int.tryParse(val) ?? 0;
                                        },
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Checkbox(
                                      value: setItem.isCompleted,
                                      activeColor: const Color(0xFF00E676),
                                      onChanged: (val) {
                                        setState(() {
                                          setItem.isCompleted = val ?? false;
                                          if (setItem.isCompleted == true) {
                                            _startRestTimer();
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _addCustomExercise,
                        child: const Text('Add Exercise'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _finishWorkout,
                        child: const Text('Finish Workout', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
