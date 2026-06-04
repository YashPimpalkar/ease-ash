import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/data_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/diary_model.dart';
import 'diary_writer_screen.dart';
import 'package:isar/isar.dart';
import '../../auth/presentation/auth_provider.dart';


class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  List<DiaryEntry> _diaryEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final db = ref.read(databaseServiceProvider);
    final email = ref.read(authProvider).email ?? '';
    final entries = await db.diaryEntries.filter().userEmailEqualTo(email).sortByDateDesc().findAll();
    setState(() {
      _diaryEntries = entries;
      _isLoading = false;
    });
  }

  Future<void> _deleteEntry(int id) async {
    final dataService = ref.read(dataServiceProvider);
    await dataService.deleteDiaryEntry(id);
    _loadEntries();
  }

  void _showEntryDetail(DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E0E1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF22223F)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Text(entry.moodEmoji, style: const TextStyle(fontSize: 28)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    entry.content,
                    style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCardDecoration(
                      borderClr: Color(0xFF6C63FF).withAlpha(60),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology, color: Color(0xFF00E6FF), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'AI Emotional Analysis',
                              style: TextStyle(color: Color(0xFF00E6FF), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.aiFeedback ?? 'No analysis generated for this entry.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _openEntryWriter() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const DiaryWriterScreen()),
    );

    if (success == true) {
      _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Diary'),
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
                    // AI Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.sentiment_satisfied_alt, color: Color(0xFF6C63FF)),
                              SizedBox(width: 8),
                              Text(
                                'AI Sentiment Insights',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _diaryEntries.isEmpty
                                ? 'Write diary entries to see your weekly emotional analysis and helpful feedback from our smart assistant.'
                                : 'You have logged ${_diaryEntries.length} diary entries. The AI assistant helps evaluate your mood patterns to recommend self-development tasks.',
                            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Diary Log',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    _diaryEntries.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AppTheme.glassCardDecoration(),
                            child: const Center(
                              child: Text(
                                'No diary entries recorded. Tap "+" to write today\'s entry!',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                          )
                        : Column(
                            children: _diaryEntries.map((entry) {
                              return Dismissible(
                                key: Key(entry.id.toString()),
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
                                onDismissed: (dir) => _deleteEntry(entry.id),
                                child: Card(
                                  color: const Color(0xFF131326),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    onTap: () => _showEntryDetail(entry),
                                    leading: Text(
                                      entry.moodEmoji,
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                    title: Text(
                                      entry.title,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${entry.date.day}/${entry.date.month}/${entry.date.year} • ${entry.content}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                    trailing: const Icon(Icons.chevron_right, color: Colors.white30),
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
        heroTag: 'diary_fab',
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: _openEntryWriter,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
