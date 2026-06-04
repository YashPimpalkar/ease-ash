import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/diary_model.dart';
import '../../auth/presentation/auth_provider.dart';


class DiaryWriterScreen extends ConsumerStatefulWidget {
  const DiaryWriterScreen({super.key});

  @override
  ConsumerState<DiaryWriterScreen> createState() => _DiaryWriterScreenState();
}

class _DiaryWriterScreenState extends ConsumerState<DiaryWriterScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  double _moodValue = 3.0; // Default: Neutral/Fine
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _getMoodEmoji(double value) {
    if (value < 1.5) return '😢';
    if (value < 2.5) return '😕';
    if (value < 3.5) return '😊';
    if (value < 4.5) return '😄';
    return '🔥';
  }

  String _getMoodLabel(double value) {
    if (value < 1.5) return 'Sad / Stressed';
    if (value < 2.5) return 'Anxious / Tired';
    if (value < 3.5) return 'Good / Peaceful';
    if (value < 4.5) return 'Happy / Productive';
    return 'Phenomenal / Unstoppable';
  }

  Future<void> _saveEntry() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out both the title and content.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final emoji = _getMoodEmoji(_moodValue);

    // Call AI analyzer
    final aiService = ref.read(aiServiceProvider);
    final feedback = await aiService.analyzeDiaryEntry(title, content);

    // Write to Isar
    final db = ref.read(databaseServiceProvider);
    final email = ref.read(authProvider).email ?? '';
    final entry = DiaryEntry(
      title: title,
      content: content,
      date: DateTime.now(),
      moodEmoji: emoji,
      moodValue: _moodValue,
      aiFeedback: feedback,
      isSynced: false,
      userEmail: email,
    );

    await db.isar.writeTxn(() async {
      await db.diaryEntries.put(entry);
    });

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _getMoodEmoji(_moodValue);
    final label = _getMoodLabel(_moodValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Diary Entry'),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _isSaving
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                      const SizedBox(height: 24),
                      Text(
                        'AI is analyzing entry sentiment...',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Generating emotional insights & feedback...',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'Entry Title',
                        hintStyle: TextStyle(color: Colors.white24),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Mood Selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCardDecoration(),
                      child: Column(
                        children: [
                          const Text(
                            'How are you feeling today?',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                emoji,
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                label,
                                style: const TextStyle(color: Color(0xFF00E6FF), fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: _moodValue,
                            min: 1.0,
                            max: 5.0,
                            divisions: 4,
                            activeColor: const Color(0xFF6C63FF),
                            inactiveColor: Colors.white10,
                            onChanged: (val) {
                              setState(() {
                                _moodValue = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _contentController,
                      style: const TextStyle(color: Colors.white, height: 1.5),
                      maxLines: 12,
                      decoration: const InputDecoration(
                        hintText: 'Dear Diary, today was...',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _saveEntry,
                        child: const Text('Save Entry & Run AI Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
