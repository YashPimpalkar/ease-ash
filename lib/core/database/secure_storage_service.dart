import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  // Keys constants
  static const _keyGroqApiKey = 'groq_api_key';
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyMongoDbUri = 'mongodb_uri';
  static const _keyStartingBalance = 'starting_bank_balance';

  // Default values provided by user
  static const String defaultMongoUri = 'mongodb+srv://secureher:secureher@cluster0.w9p685i.mongodb.net/easyash?appName=Cluster0';

  Future<void> initDefaults() async {
    final groqKey = await getGroqApiKey();
    if (groqKey == null) {
      final envKey = dotenv.env['GROQ_API_KEY'] ?? '';
      await saveGroqApiKey(envKey);
    }
    final geminiKey = await getGeminiApiKey();
    if (geminiKey == null) {
      final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      await saveGeminiApiKey(envKey);
    }
    final mongoUri = await getMongoDbUri();
    if (mongoUri == null) {
      await saveMongoDbUri(defaultMongoUri);
    }
    final startingBal = await getStartingBalance();
    if (startingBal == null) {
      await saveStartingBalance(0.0);
    }
  }

  // Groq API Key
  Future<String?> getGroqApiKey() async {
    return await _storage.read(key: _keyGroqApiKey);
  }

  Future<void> saveGroqApiKey(String value) async {
    await _storage.write(key: _keyGroqApiKey, value: value);
  }

  // Gemini API Key
  Future<String?> getGeminiApiKey() async {
    return await _storage.read(key: _keyGeminiApiKey);
  }

  Future<void> saveGeminiApiKey(String value) async {
    await _storage.write(key: _keyGeminiApiKey, value: value);
  }

  // MongoDB URI
  Future<String?> getMongoDbUri() async {
    return await _storage.read(key: _keyMongoDbUri);
  }

  Future<void> saveMongoDbUri(String value) async {
    await _storage.write(key: _keyMongoDbUri, value: value);
  }

  // Starting Bank Balance
  Future<double?> getStartingBalance() async {
    final val = await _storage.read(key: _keyStartingBalance);
    return val != null ? double.tryParse(val) : null;
  }

  Future<void> saveStartingBalance(double value) async {
    await _storage.write(key: _keyStartingBalance, value: value.toString());
  }

  // Clear all data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

final startingBalanceProvider = StateNotifierProvider<StartingBalanceNotifier, double>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return StartingBalanceNotifier(storage);
});

class StartingBalanceNotifier extends StateNotifier<double> {
  final SecureStorageService _storage;

  StartingBalanceNotifier(this._storage) : super(0.0) {
    loadStartingBalance();
  }

  Future<void> loadStartingBalance() async {
    final balance = await _storage.getStartingBalance();
    state = balance ?? 0.0;
  }

  Future<void> updateStartingBalance(double value) async {
    await _storage.saveStartingBalance(value);
    state = value;
  }
}
