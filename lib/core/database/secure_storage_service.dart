import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../features/auth/presentation/auth_provider.dart';


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
  static const _keyCurrentUserEmail = 'current_user_email';
  static const _keyBiometricUserEmail = 'biometric_user_email';
  static const _prefixUserPwHash = 'user_pw_hash_';
  static const _prefixUserRole = 'user_role_';
  static const _prefixUserBiometric = 'user_biometric_enabled_';

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
      final envUri = dotenv.env['MONGODB_URI'] ?? defaultMongoUri;
      await saveMongoDbUri(envUri);
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
  Future<double?> getStartingBalance([String? email]) async {
    final key = email == null ? _keyStartingBalance : '${_keyStartingBalance}_${email.toLowerCase()}';
    final val = await _storage.read(key: key);
    return val != null ? double.tryParse(val) : null;
  }

  Future<void> saveStartingBalance(double value, [String? email]) async {
    final key = email == null ? _keyStartingBalance : '${_keyStartingBalance}_${email.toLowerCase()}';
    await _storage.write(key: key, value: value.toString());
  }

  // Auth Helpers
  Future<String?> getCurrentUserEmail() async {
    return await _storage.read(key: _keyCurrentUserEmail);
  }

  Future<void> saveCurrentUserEmail(String? value) async {
    if (value == null) {
      await _storage.delete(key: _keyCurrentUserEmail);
    } else {
      await _storage.write(key: _keyCurrentUserEmail, value: value);
    }
  }

  Future<String?> getBiometricUserEmail() async {
    return await _storage.read(key: _keyBiometricUserEmail);
  }

  Future<void> saveBiometricUserEmail(String? value) async {
    if (value == null) {
      await _storage.delete(key: _keyBiometricUserEmail);
    } else {
      await _storage.write(key: _keyBiometricUserEmail, value: value);
    }
  }

  Future<String?> getUserPasswordHash(String email) async {
    return await _storage.read(key: '$_prefixUserPwHash${email.toLowerCase()}');
  }

  Future<void> saveUserPasswordHash(String email, String hash) async {
    await _storage.write(key: '$_prefixUserPwHash${email.toLowerCase()}', value: hash);
  }

  Future<String?> getUserRole(String email) async {
    return await _storage.read(key: '$_prefixUserRole${email.toLowerCase()}');
  }

  Future<void> saveUserRole(String email, String role) async {
    await _storage.write(key: '$_prefixUserRole${email.toLowerCase()}', value: role);
  }

  Future<bool> isBiometricEnabled(String email) async {
    final val = await _storage.read(key: '$_prefixUserBiometric${email.toLowerCase()}');
    return val == 'true';
  }

  Future<void> saveBiometricEnabled(String email, bool enabled) async {
    await _storage.write(key: '$_prefixUserBiometric${email.toLowerCase()}', value: enabled.toString());
  }

  // Clear all data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

final startingBalanceProvider = StateNotifierProvider<StartingBalanceNotifier, double>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final auth = ref.watch(authProvider);
  final email = auth.email ?? '';
  return StartingBalanceNotifier(storage, email);
});

class StartingBalanceNotifier extends StateNotifier<double> {
  final SecureStorageService _storage;
  final String _email;

  StartingBalanceNotifier(this._storage, this._email) : super(0.0) {
    loadStartingBalance();
  }

  Future<void> loadStartingBalance() async {
    if (_email.isEmpty) {
      state = 0.0;
      return;
    }
    final balance = await _storage.getStartingBalance(_email);
    state = balance ?? 0.0;
  }

  Future<void> updateStartingBalance(double value) async {
    if (_email.isEmpty) return;
    await _storage.saveStartingBalance(value, _email);
    state = value;
  }
}
