import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/database/database_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/calendar_event_model.dart';
import 'package:isar/isar.dart';
import '../../auth/presentation/auth_provider.dart';


class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<CalendarEvent> _allEvents = [];
  Map<DateTime, List<CalendarEvent>> _eventsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final db = ref.read(databaseServiceProvider);
    final email = ref.read(authProvider).email ?? '';
    final eventsList = await db.isar.calendarEvents.filter().userEmailEqualTo(email).sortByStartTime().findAll();

    // Map events by day (stripping time)
    final Map<DateTime, List<CalendarEvent>> mapped = {};
    for (final event in eventsList) {
      final dayKey = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
      if (mapped[dayKey] == null) {
        mapped[dayKey] = [];
      }
      mapped[dayKey]!.add(event);
    }

    setState(() {
      _allEvents = eventsList;
      _eventsMap = mapped;
      _isLoading = false;
    });
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _eventsMap[dayKey] ?? [];
  }

  bool _checkConflict(DateTime start, DateTime end) {
    for (final event in _allEvents) {
      if (start.isBefore(event.endTime) && end.isAfter(event.startTime)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addEvent(
    String title,
    String? description,
    DateTime start,
    DateTime end,
    String category,
    String colorHex,
    String recurrence,
  ) async {
    final db = ref.read(databaseServiceProvider);
    final email = ref.read(authProvider).email ?? '';
    final event = CalendarEvent(
      title: title.trim(),
      description: description?.trim(),
      startTime: start,
      endTime: end,
      category: category,
      colorHex: colorHex,
      recurrence: recurrence,
      isSynced: false,
      userEmail: email,
    );

    await db.isar.writeTxn(() async {
      await db.isar.calendarEvents.put(event);
    });
    _loadEvents();
  }

  Future<void> _deleteEvent(int id) async {
    final db = ref.read(databaseServiceProvider);
    await db.isar.writeTxn(() async {
      await db.isar.calendarEvents.delete(id);
    });
    _loadEvents();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'meeting':
        return const Color(0xFFFF5252);
      case 'gym':
        return const Color(0xFF00E676);
      case 'birthday':
        return const Color(0xFF00E6FF);
      case 'task':
        return const Color(0xFF8F88FF);
      default:
        return Colors.amberAccent;
    }
  }

  void _showAddEventSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    
    DateTime selectedStart = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      DateTime.now().hour,
      0,
    );
    DateTime selectedEnd = selectedStart.add(const Duration(hours: 1));
    String selectedCategory = 'meeting';
    String selectedRecurrence = 'none';
    bool hasConflict = false;

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
            hasConflict = _checkConflict(selectedStart, selectedEnd);

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
                      'Schedule Event',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    if (hasConflict)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF5252).withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFF5252)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Schedule Conflict: Overlaps with an existing event!',
                                style: TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
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
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Start Time', style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedStart),
                            );
                            if (pickedTime != null) {
                              setModalState(() {
                                selectedStart = DateTime(
                                  selectedStart.year,
                                  selectedStart.month,
                                  selectedStart.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                                if (selectedEnd.isBefore(selectedStart)) {
                                  selectedEnd = selectedStart.add(const Duration(hours: 1));
                                }
                              });
                            }
                          },
                          child: Text(
                            TimeOfDay.fromDateTime(selectedStart).format(context),
                            style: const TextStyle(color: Color(0xFF00E6FF), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('End Time', style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedEnd),
                            );
                            if (pickedTime != null) {
                              setModalState(() {
                                selectedEnd = DateTime(
                                  selectedEnd.year,
                                  selectedEnd.month,
                                  selectedEnd.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          },
                          child: Text(
                            TimeOfDay.fromDateTime(selectedEnd).format(context),
                            style: const TextStyle(color: Color(0xFF00E6FF), fontWeight: FontWeight.bold),
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
                              const Text('Category', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              DropdownButton<String>(
                                value: selectedCategory,
                                dropdownColor: const Color(0xFF131326),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white),
                                items: ['meeting', 'gym', 'birthday', 'task', 'other'].map((c) {
                                  return DropdownMenuItem(value: c, child: Text(c.toUpperCase()));
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Recurrence', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              DropdownButton<String>(
                                value: selectedRecurrence,
                                dropdownColor: const Color(0xFF131326),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white),
                                items: ['none', 'daily', 'weekly', 'yearly'].map((r) {
                                  return DropdownMenuItem(value: r, child: Text(r.toUpperCase()));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => selectedRecurrence = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          if (titleController.text.isNotEmpty && selectedEnd.isAfter(selectedStart)) {
                            final colorHex = '#${_getCategoryColor(selectedCategory).value.toRadixString(16).substring(2)}';
                            _addEvent(
                              titleController.text,
                              descController.text.isEmpty ? null : descController.text,
                              selectedStart,
                              selectedEnd,
                              selectedCategory,
                              colorHex,
                              selectedRecurrence,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Add Event', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final dailyEvents = _getEventsForDay(_selectedDay!);

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
                        'My Calendar',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: AppTheme.glassCardDecoration(),
                              child: TableCalendar(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                calendarFormat: _calendarFormat,
                                selectedDayPredicate: (day) {
                                  return isSameDay(_selectedDay, day);
                                },
                                eventLoader: _getEventsForDay,
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                },
                                onFormatChanged: (format) {
                                  setState(() {
                                    _calendarFormat = format;
                                  });
                                },
                                onPageChanged: (focusedDay) {
                                  _focusedDay = focusedDay;
                                },
                                calendarStyle: const CalendarStyle(
                                  defaultTextStyle: TextStyle(color: Colors.white),
                                  weekendTextStyle: TextStyle(color: Colors.white60),
                                  outsideDaysVisible: false,
                                  selectedDecoration: BoxDecoration(
                                    color: Color(0xFF6C63FF),
                                    shape: BoxShape.circle,
                                  ),
                                  todayDecoration: BoxDecoration(
                                    color: Color(0xFF00E6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  markerDecoration: BoxDecoration(
                                    color: Color(0xFFFF8A00),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                headerStyle: const HeaderStyle(
                                  formatButtonVisible: true,
                                  titleCentered: true,
                                  titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
                                  formatButtonTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  formatButtonDecoration: BoxDecoration(
                                    color: Color(0xFF00E6FF),
                                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                                  ),
                                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Events for Today',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: AppTheme.glassCardDecoration(),
                              child: dailyEvents.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20.0),
                                        child: Text(
                                          'No events scheduled today.',
                                          style: TextStyle(color: Colors.white60),
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: dailyEvents.map((event) {
                                        return Dismissible(
                                          key: Key(event.id.toString()),
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
                                          onDismissed: (dir) => _deleteEvent(event.id),
                                          child: Card(
                                            color: const Color(0xFF131326),
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            child: ListTile(
                                              leading: Container(
                                                width: 4,
                                                height: 40,
                                                color: _getCategoryColor(event.category),
                                              ),
                                              title: Text(
                                                event.title,
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')} - '
                                                '${event.endTime.hour.toString().padLeft(2, '0')}:${event.endTime.minute.toString().padLeft(2, '0')}'
                                                '${event.recurrence != 'none' ? ' (${event.recurrence})' : ''}',
                                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                                              ),
                                              trailing: Text(
                                                event.category.toUpperCase(),
                                                style: TextStyle(
                                                  color: _getCategoryColor(event.category),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab',
        backgroundColor: const Color(0xFF00E6FF),
        onPressed: _showAddEventSheet,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
