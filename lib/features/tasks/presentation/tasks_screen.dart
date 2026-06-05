import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/data_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/task_model.dart';
import 'package:isar/isar.dart';
import '../../auth/presentation/auth_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final db = ref.read(databaseServiceProvider);
    final email = ref.read(authProvider).email ?? '';
    final tasksList = await db.isar.tasks.filter().userEmailEqualTo(email).sortByDueDate().findAll();

    // Bootstrap default habits if Isar is completely empty for habits
    final habitCount = tasksList.where((t) => t.category == 'Habit').length;
    if (habitCount == 0 && tasksList.isEmpty) {
      final now = DateTime.now();
      final defaultHabits = [
        Task(
          title: 'Read 10 pages',
          dueDate: DateTime(now.year, now.month, now.day, 23, 59),
          priority: 'low',
          category: 'Habit',
          createdAt: now,
          userEmail: email,
        ),
        Task(
          title: 'Drink 3L Water',
          dueDate: DateTime(now.year, now.month, now.day, 23, 59),
          priority: 'medium',
          category: 'Habit',
          createdAt: now,
          userEmail: email,
        ),
        Task(
          title: 'Gym Workout',
          dueDate: DateTime(now.year, now.month, now.day, 23, 59),
          priority: 'high',
          category: 'Habit',
          createdAt: now,
          userEmail: email,
        ),
      ];

      final dataService = ref.read(dataServiceProvider);
      for (final habit in defaultHabits) {
        await dataService.saveTask(habit);
      }

      final updatedTasks = await db.isar.tasks.filter().userEmailEqualTo(email).sortByDueDate().findAll();
      setState(() {
        _tasks = updatedTasks;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _tasks = tasksList;
      _isLoading = false;
    });
  }

  Future<void> _toggleTaskCompleted(Task task) async {
    task.isCompleted = !task.isCompleted;
    task.isSynced = false;
    final dataService = ref.read(dataServiceProvider);
    await dataService.saveTask(task);
    _loadTasks();
  }

  Future<void> _toggleSubtaskCompleted(Task task, int subtaskIndex) async {
    // Copy subtask completion status to modify it
    final newList = List<bool>.from(task.subtaskCompleted);
    newList[subtaskIndex] = !newList[subtaskIndex];
    task.subtaskCompleted = newList;
    task.isSynced = false;

    final dataService = ref.read(dataServiceProvider);
    await dataService.saveTask(task);
    _loadTasks();
  }

  Future<void> _deleteTask(int id) async {
    final dataService = ref.read(dataServiceProvider);
    await dataService.deleteTask(id);
    _loadTasks();
  }

  Future<void> _addTask(
    String title,
    String? description,
    DateTime dueDate,
    String priority,
    String category,
    List<String> subtasks,
  ) async {
    final email = ref.read(authProvider).email ?? '';
    final task = Task(
      title: title.trim(),
      description: description?.trim(),
      dueDate: dueDate,
      priority: priority.toLowerCase(),
      category: category,
      subtasks: subtasks,
      subtaskCompleted: List<bool>.filled(subtasks.length, false),
      createdAt: DateTime.now(),
      isSynced: false,
      userEmail: email,
    );

    final dataService = ref.read(dataServiceProvider);
    await dataService.saveTask(task);
    _loadTasks();
  }

  // --- Habit CRUD ---

  void _showAddHabitSheet() {
    final titleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Daily Habit',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Habit Title',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E6FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      final now = DateTime.now();
                      _addTask(
                        titleController.text,
                        null,
                        DateTime(now.year, now.month, now.day, 23, 59),
                        'medium',
                        'Habit',
                        [],
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add Habit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showEditHabitSheet(Task habit) {
    final titleController = TextEditingController(text: habit.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit Habit',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Habit Title',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E6FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isNotEmpty) {
                      habit.title = titleController.text.trim();
                      habit.isSynced = false;
                      final dataService = ref.read(dataServiceProvider);
                      await dataService.saveTask(habit);
                      _loadTasks();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteHabitDialog(Task habit) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131326),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Habit', style: TextStyle(color: Colors.white)),
          content: Text(
            'Remove "${habit.title}" from your daily habits?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _deleteTask(habit.id);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAddTaskSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final subtaskController = TextEditingController();
    
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedPriority = 'Medium';
    String selectedCategory = 'Personal';
    List<String> tempSubtasks = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create New Task',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF8A00))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF8A00))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Due Date:', style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Priority', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              DropdownButton<String>(
                                value: selectedPriority,
                                dropdownColor: const Color(0xFF131326),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white),
                                items: ['Low', 'Medium', 'High'].map((p) {
                                  return DropdownMenuItem(value: p, child: Text(p));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => selectedPriority = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Category', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              DropdownButton<String>(
                                value: selectedCategory,
                                dropdownColor: const Color(0xFF131326),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white),
                                items: ['Personal', 'Work', 'Gym', 'Habit'].map((c) {
                                  return DropdownMenuItem(value: c, child: Text(c));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => selectedCategory = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Subtasks Checklist', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...tempSubtasks.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.subdirectory_arrow_right, color: Color(0xFFFF8A00), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(entry.value, style: const TextStyle(color: Colors.white)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                              onPressed: () {
                                setModalState(() {
                                  tempSubtasks.removeAt(entry.key);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: subtaskController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Add subtask item...',
                              hintStyle: TextStyle(color: Colors.white24),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF00E6FF)),
                          onPressed: () {
                            if (subtaskController.text.isNotEmpty) {
                              setModalState(() {
                                tempSubtasks.add(subtaskController.text.trim());
                                subtaskController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8A00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          if (titleController.text.isNotEmpty) {
                            _addTask(
                              titleController.text,
                              descController.text.isEmpty ? null : descController.text,
                              selectedDate,
                              selectedPriority,
                              selectedCategory,
                              tempSubtasks,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFF8A00);
      default:
        return const Color(0xFF00E676);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = _tasks.where((t) => t.category == 'Habit').toList();
    final activeTasks = _tasks.where((t) => t.category != 'Habit').toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E6FF)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Task Tracker',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily Habits',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E6FF), size: 22),
                                tooltip: 'Add Habit',
                                onPressed: _showAddHabitSheet,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: AppTheme.glassCardDecoration(),
                            child: habits.isEmpty
                                ? const Center(child: Text('No daily habits configured', style: TextStyle(color: Colors.white38)))
                                : Column(
                                    children: habits.map((habit) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                habit.title,
                                                style: TextStyle(
                                                  color: habit.isCompleted ? Colors.white38 : Colors.white,
                                                  decoration: habit.isCompleted ? TextDecoration.lineThrough : null,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Checkbox(
                                                  value: habit.isCompleted,
                                                  activeColor: const Color(0xFF00E6FF),
                                                  onChanged: (val) => _toggleTaskCompleted(habit),
                                                ),
                                                InkWell(
                                                  onTap: () => _showEditHabitSheet(habit),
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(6.0),
                                                    child: Icon(Icons.edit_outlined, color: Color(0xFF00E6FF), size: 18),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () => _showDeleteHabitDialog(habit),
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(6.0),
                                                    child: Icon(Icons.delete_outline, color: Color(0xFFFF5252), size: 18),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Active Tasks',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          activeTasks.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: AppTheme.glassCardDecoration(),
                                  child: const Center(
                                    child: Text(
                                      'No pending tasks. Celebrate!',
                                      style: TextStyle(color: Colors.white60),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: activeTasks.map((task) {
                                    final totalSub = task.subtasks.length;
                                    final completedSub = task.subtaskCompleted.where((c) => c).length;
                                    final hasSubtasks = totalSub > 0;

                                    return Dismissible(
                                      key: Key(task.id.toString()),
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
                                      onDismissed: (dir) => _deleteTask(task.id),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: AppTheme.glassCardDecoration(
                                          borderClr: _getPriorityColor(task.priority).withAlpha(40),
                                        ),
                                        child: ExpansionTile(
                                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          iconColor: Colors.white,
                                          collapsedIconColor: Colors.white60,
                                          title: Row(
                                            children: [
                                              Checkbox(
                                                value: task.isCompleted,
                                                activeColor: const Color(0xFF00E6FF),
                                                onChanged: (val) => _toggleTaskCompleted(task),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      task.title,
                                                      style: TextStyle(
                                                        color: task.isCompleted ? Colors.white38 : Colors.white,
                                                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    if (task.description != null)
                                                      Text(
                                                        task.description!,
                                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(left: 48.0, top: 4),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getPriorityColor(task.priority).withAlpha(50),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    task.priority.toUpperCase(),
                                                    style: TextStyle(
                                                      color: _getPriorityColor(task.priority),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}',
                                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                ),
                                                const SizedBox(width: 8),
                                                if (hasSubtasks)
                                                  Text(
                                                    '($completedSub/$totalSub subtasks)',
                                                    style: const TextStyle(color: Color(0xFF00E6FF), fontSize: 11),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          children: [
                                            if (hasSubtasks)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 48.0, right: 16, bottom: 16),
                                                child: Column(
                                                  children: task.subtasks.asMap().entries.map((entry) {
                                                    final index = entry.key;
                                                    final subtaskText = entry.value;
                                                    final isSubCompleted = task.subtaskCompleted[index];

                                                    return Row(
                                                      children: [
                                                        Checkbox(
                                                          value: isSubCompleted,
                                                          activeColor: const Color(0xFF00E6FF),
                                                          onChanged: (val) => _toggleSubtaskCompleted(task, index),
                                                        ),
                                                        Text(
                                                          subtaskText,
                                                          style: TextStyle(
                                                            color: isSubCompleted ? Colors.white38 : Colors.white,
                                                            decoration: isSubCompleted ? TextDecoration.lineThrough : null,
                                                          ),
                                                        ),
                                                      ],
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
                          const SizedBox(height: 80), // Space for floating button
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasks_fab',
        backgroundColor: const Color(0xFFFF8A00),
        onPressed: _showAddTaskSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
