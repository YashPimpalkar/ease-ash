import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/ai_model_config.dart';
import 'package:isar/isar.dart';

class AiModelsScreen extends ConsumerStatefulWidget {
  const AiModelsScreen({super.key});

  @override
  ConsumerState<AiModelsScreen> createState() => _AiModelsScreenState();
}

class _AiModelsScreenState extends ConsumerState<AiModelsScreen> {
  List<AiModelConfig> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    final db = ref.read(databaseServiceProvider);
    final models = await db.isar.aiModelConfigs.where().sortByPriority().findAll();
    setState(() {
      _models = models;
      _isLoading = false;
    });
  }

  Future<void> _saveOrder() async {
    final db = ref.read(databaseServiceProvider);
    await db.isar.writeTxn(() async {
      for (int i = 0; i < _models.length; i++) {
        _models[i].priority = i + 1;
        await db.isar.aiModelConfigs.put(_models[i]);
      }
    });
  }

  Future<void> _toggleEnabled(AiModelConfig model, bool value) async {
    final db = ref.read(databaseServiceProvider);
    model.isEnabled = value;
    await db.isar.writeTxn(() async {
      await db.isar.aiModelConfigs.put(model);
    });
    _loadModels();
  }

  Future<void> _deleteModel(AiModelConfig model) async {
    final db = ref.read(databaseServiceProvider);
    await db.isar.writeTxn(() async {
      await db.isar.aiModelConfigs.delete(model.id);
    });
    _loadModels();
  }

  Future<void> _addModel(String displayName, String modelName) async {
    final db = ref.read(databaseServiceProvider);
    final newModel = AiModelConfig(
      modelName: modelName.trim(),
      displayName: displayName.trim(),
      priority: _models.length + 1,
      isEnabled: true,
    );
    await db.isar.writeTxn(() async {
      await db.isar.aiModelConfigs.put(newModel);
    });
    _loadModels();
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final modelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131326),
          title: const Text('Add Custom AI Model', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Display Name (e.g. Llama 3 8B)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Model Identifier (e.g. llama3-8b-8192)',
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E6FF)),
              onPressed: () {
                if (nameController.text.isNotEmpty && modelController.text.isNotEmpty) {
                  _addModel(nameController.text, modelController.text);
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
        title: const Text('AI Models Manager'),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E6FF)))
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      key: ValueKey('header_text'),
                      child: Text(
                        'Drag to prioritize model order. The app will try the top model first, and fall back sequentially on failure (HTTP 429).',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: _models.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _models.removeAt(oldIndex);
                            _models.insert(newIndex, item);
                          });
                          _saveOrder();
                        },
                        itemBuilder: (context, index) {
                          final model = _models[index];
                          return Card(
                            key: ValueKey(model.id),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: const Color(0xFF131326),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF6C63FF).withAlpha(40),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Color(0xFF00E6FF), fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                model.displayName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                model.modelName,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: model.isEnabled,
                                    activeColor: const Color(0xFF00E6FF),
                                    onChanged: (val) => _toggleEnabled(model, val),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
                                    onPressed: () => _deleteModel(model),
                                  ),
                                  const Icon(Icons.drag_handle, color: Colors.white30),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'ai_models_fab',
        backgroundColor: const Color(0xFF00E6FF),
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
