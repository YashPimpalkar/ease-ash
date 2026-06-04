import 'package:isar/isar.dart';

part 'ai_model_config.g.dart';

@collection
class AiModelConfig {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String modelName;

  late String displayName;

  @Index()
  late int priority;

  late bool isEnabled;

  AiModelConfig({
    this.id = Isar.autoIncrement,
    required this.modelName,
    required this.displayName,
    required this.priority,
    this.isEnabled = true,
  });
}
