import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../database/database_service.dart';
import '../database/secure_storage_service.dart';
import '../../features/settings/domain/ai_model_config.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AiService(dbService, secureStorage);
});

class AiService {
  final DatabaseService _db;
  final SecureStorageService _secureStorage;
  final Dio _dio;

  AiService(this._db, this._secureStorage) : _dio = Dio();

  /// Sends messages to Groq API with automatic model failover.
  Future<String> getChatResponse(List<Map<String, String>> messages) async {
    final apiKey = await _secureStorage.getGroqApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key is not configured. Please configure it in settings.');
    }

    // Get enabled models sorted by priority
    final models = await _db.isar.aiModelConfigs
        .filter()
        .isEnabledEqualTo(true)
        .sortByPriority()
        .findAll();

    if (models.isEmpty) {
      throw Exception('No AI models are enabled. Please enable at least one model in settings.');
    }

    DioException? lastError;

    for (final modelConfig in models) {
      final modelName = modelConfig.modelName;
      try {
        print('AI Service: Trying model $modelName (${modelConfig.displayName})...');
        
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
          data: {
            'model': modelName,
            'messages': messages,
            'temperature': 0.7,
          },
        );

        if (response.statusCode == 200) {
          final data = response.data;
          // Groq returns JSON. Dio automatically parses if content-type is json.
          // Depending on Dio configurations, it might be a Map or String.
          final Map<String, dynamic> jsonMap = data is String ? json.decode(data) : data;
          final content = jsonMap['choices'][0]['message']['content'] as String;
          print('AI Service: Success using model $modelName!');
          return content;
        }
      } on DioException catch (e) {
        lastError = e;
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        print('AI Service: Model $modelName failed with status $statusCode. Error: ${e.message}. Data: $responseData');
        
        final responseStr = responseData?.toString().toLowerCase() ?? '';
        final isModelConfigError = responseStr.contains('decommissioned') || 
                                   responseStr.contains('deprecated') || 
                                   responseStr.contains('not found') || 
                                   responseStr.contains('unknown model');

        // Failover if rate limited (429), server error (5xx), timeout, or model decommissioned/not found
        if (statusCode == 429 || 
            (statusCode != null && statusCode >= 500) || 
            e.type != DioExceptionType.badResponse ||
            isModelConfigError) {
          print('AI Service: Model error, rate limit or network issue. Switching to fallback model...');
          continue; // Try next model
        } else {
          // If it's a bad request (400) or auth issue (401), we fail immediately rather than looping
          throw Exception('Groq API error ($statusCode): ${e.message}. details: $responseData');
        }
      } catch (e) {
        print('AI Service: Unexpected error using model $modelName: $e');
        // Continue to fallback model on unexpected errors
        continue;
      }
    }

    // If we exhausted all models, throw the last error or generic error
    if (lastError != null) {
      throw Exception('All Groq models failed. Last error: ${lastError.message}');
    } else {
      throw Exception('Failed to get response from Groq API (all models exhausted).');
    }
  }

  /// Generates emotional analysis and feedback for a diary entry.
  Future<String> analyzeDiaryEntry(String title, String content) async {
    final prompt = [
      {
        'role': 'system',
        'content': 'You are a compassionate, insightful AI diary analyst. Analyze the following journal entry. '
            'Provide a breakdown of the emotional state (sentiment), key themes/concerns, and gentle, actionable advice. '
            'Keep it structured, supportive, and concise (under 250 words).'
      },
      {
        'role': 'user',
        'content': 'Title: $title\n\nContent: $content'
      }
    ];

    try {
      return await getChatResponse(prompt);
    } catch (e) {
      return 'Could not generate AI sentiment analysis right now: $e';
    }
  }

  /// Generates budget insights based on current transactions.
  Future<String> getBudgetCoachFeedback({
    required double currentBalance,
    required double incomeTotal,
    required double expenseTotal,
    required List<Map<String, dynamic>> transactionsSummary,
  }) async {
    final txsString = transactionsSummary
        .map((t) => '- ${t['date'].toString().substring(0, 10)}: ${t['title']} (${t['category']}) -> ₹${t['amount']} (${t['isExpense'] ? 'Expense' : 'Income'})')
        .join('\n');

    final prompt = [
      {
        'role': 'system',
        'content': 'You are an expert personal finance coach. Analyze the user\'s transaction summary. '
            'Offer concise, tailored suggestions to optimize spending, increase savings, and manage their budget. '
            'Keep it under 150 words and use clear bullet points.'
      },
      {
        'role': 'user',
        'content': 'Starting/Current Balance: ₹$currentBalance\n'
            'Total Income: ₹$incomeTotal\n'
            'Total Expenses: ₹$expenseTotal\n'
            'Recent Transactions:\n$txsString'
      }
    ];

    try {
      return await getChatResponse(prompt);
    } catch (e) {
      return 'Could not generate budget advice right now: $e';
    }
  }
}
