import 'package:flutter_test/flutter_test.dart';

class MockAiModel {
  final String modelName;
  final int priority;
  bool isEnabled;

  MockAiModel({
    required this.modelName,
    required this.priority,
    this.isEnabled = true,
  });
}

void main() {
  group('AI Model Failover Engine Tests', () {
    test('Correctly selects highest priority model first and falls back on 429 rate limit', () {
      final List<MockAiModel> models = [
        MockAiModel(modelName: 'llama-70b-primary', priority: 1, isEnabled: true),
        MockAiModel(modelName: 'llama-70b-secondary', priority: 2, isEnabled: true),
        MockAiModel(modelName: 'gemma-9b-backup', priority: 3, isEnabled: true),
      ];

      // Simulate client execution
      final List<String> triedModels = [];
      String? successModel;

      // Mock API function that fails on the first two models and succeeds on gemma
      String callApi(String modelName) {
        triedModels.add(modelName);
        if (modelName == 'llama-70b-primary') {
          throw Exception('429 Rate Limit Exceeded');
        }
        if (modelName == 'llama-70b-secondary') {
          throw Exception('503 Service Unavailable');
        }
        return 'Success';
      }

      // Sort models by priority
      models.sort((a, b) => a.priority.compareTo(b.priority));
      final enabledModels = models.where((m) => m.isEnabled).toList();

      for (final model in enabledModels) {
        try {
          final res = callApi(model.modelName);
          if (res == 'Success') {
            successModel = model.modelName;
            break;
          }
        } catch (e) {
          // Failover to next model
          continue;
        }
      }

      expect(triedModels, equals([
        'llama-70b-primary',
        'llama-70b-secondary',
        'gemma-9b-backup',
      ]));
      expect(successModel, equals('gemma-9b-backup'));
    });
  });
}
