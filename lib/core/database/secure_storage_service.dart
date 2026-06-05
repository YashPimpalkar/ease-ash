import 'dart:convert';
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
  static const _keyStartingBalanceDate = 'starting_bank_balance_date';
  static const _keyTitleCategoryMappings = 'title_category_mappings';
  static const _keyBudgetLimits = 'budget_limits';
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

  Future<DateTime?> getStartingBalanceDate([String? email]) async {
    final key = email == null ? _keyStartingBalanceDate : '${_keyStartingBalanceDate}_${email.toLowerCase()}';
    final val = await _storage.read(key: key);
    return val != null ? DateTime.tryParse(val) : null;
  }

  Future<void> saveStartingBalanceDate(DateTime value, [String? email]) async {
    final key = email == null ? _keyStartingBalanceDate : '${_keyStartingBalanceDate}_${email.toLowerCase()}';
    await _storage.write(key: key, value: value.toIso8601String());
  }

  Future<Map<String, String>> getTitleCategoryMappings([String? email]) async {
    final key = email == null ? _keyTitleCategoryMappings : '${_keyTitleCategoryMappings}_${email.toLowerCase()}';
    final val = await _storage.read(key: key);
    if (val == null) return {};
    try {
      final decoded = jsonDecode(val) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTitleCategoryMappings(Map<String, String> mappings, [String? email]) async {
    final key = email == null ? _keyTitleCategoryMappings : '${_keyTitleCategoryMappings}_${email.toLowerCase()}';
    await _storage.write(key: key, value: jsonEncode(mappings));
  }

  // Username
  Future<String?> getUsername(String email) async {
    return await _storage.read(key: 'username_${email.toLowerCase()}');
  }

  Future<void> saveUsername(String email, String username) async {
    await _storage.write(key: 'username_${email.toLowerCase()}', value: username);
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

  // Budget Limits
  Future<Map<String, double>?> getBudgetLimits([String? email]) async {
    final key = email == null ? _keyBudgetLimits : '${_keyBudgetLimits}_${email.toLowerCase()}';
    final val = await _storage.read(key: key);
    if (val == null) return null;
    try {
      final decoded = jsonDecode(val) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBudgetLimits(Map<String, double> limits, [String? email]) async {
    final key = email == null ? _keyBudgetLimits : '${_keyBudgetLimits}_${email.toLowerCase()}';
    await _storage.write(key: key, value: jsonEncode(limits));
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

final startingBalanceDateProvider = StateNotifierProvider<StartingBalanceDateNotifier, DateTime>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final auth = ref.watch(authProvider);
  final email = auth.email ?? '';
  return StartingBalanceDateNotifier(storage, email);
});

class StartingBalanceDateNotifier extends StateNotifier<DateTime> {
  final SecureStorageService _storage;
  final String _email;

  static final DateTime defaultDate = DateTime(2020, 1, 1);

  StartingBalanceDateNotifier(this._storage, this._email) : super(defaultDate) {
    loadStartingBalanceDate();
  }

  Future<void> loadStartingBalanceDate() async {
    if (_email.isEmpty) {
      state = defaultDate;
      return;
    }
    final date = await _storage.getStartingBalanceDate(_email);
    state = date ?? defaultDate;
  }

  Future<void> updateStartingBalanceDate(DateTime value) async {
    if (_email.isEmpty) return;
    await _storage.saveStartingBalanceDate(value, _email);
    state = value;
  }
}

final titleCategoryMappingsProvider = StateNotifierProvider<TitleCategoryMappingsNotifier, Map<String, String>>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final auth = ref.watch(authProvider);
  final email = auth.email ?? '';
  return TitleCategoryMappingsNotifier(storage, email);
});

class TitleCategoryMappingsNotifier extends StateNotifier<Map<String, String>> {
  final SecureStorageService _storage;
  final String _email;

  TitleCategoryMappingsNotifier(this._storage, this._email) : super({}) {
    loadMappings();
  }

  Future<void> loadMappings() async {
    if (_email.isEmpty) return;
    final maps = await _storage.getTitleCategoryMappings(_email);
    state = maps;
  }

  Future<void> updateMapping(String title, String category) async {
    if (_email.isEmpty) return;
    final updated = Map<String, String>.from(state);
    updated[title.toLowerCase().trim()] = category;
    state = updated;
    await _storage.saveTitleCategoryMappings(state, _email);
  }

  Future<void> removeMapping(String title) async {
    if (_email.isEmpty) return;
    final updated = Map<String, String>.from(state);
    updated.remove(title.toLowerCase().trim());
    state = updated;
    await _storage.saveTitleCategoryMappings(state, _email);
  }
}

final budgetLimitsProvider = StateNotifierProvider<BudgetLimitsNotifier, Map<String, double>>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final auth = ref.watch(authProvider);
  final email = auth.email ?? '';
  return BudgetLimitsNotifier(storage, email);
});

class BudgetLimitsNotifier extends StateNotifier<Map<String, double>> {
  final SecureStorageService _storage;
  final String _email;

  static const Map<String, double> _defaultLimits = {
    'Food': 5000.0,
    'Entertainment': 3000.0,
    'Utilities': 8000.0,
    'Rent': 15000.0,
    'Gym': 2000.0,
    'Transport': 3000.0,
    'Other': 4000.0,
  };

  BudgetLimitsNotifier(this._storage, this._email) : super(_defaultLimits) {
    _load();
  }

  Future<void> _load() async {
    if (_email.isEmpty) return;
    final saved = await _storage.getBudgetLimits(_email);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    } else {
      // Persist defaults on first load
      await _storage.saveBudgetLimits(_defaultLimits, _email);
    }
  }

  Future<void> addCategory(String name, double amount) async {
    final updated = Map<String, double>.from(state);
    updated[name] = amount;
    state = updated;
    await _storage.saveBudgetLimits(state, _email);
  }

  Future<void> updateCategory(String oldName, String newName, double amount) async {
    final updated = Map<String, double>.from(state);
    if (oldName != newName) updated.remove(oldName);
    updated[newName] = amount;
    state = updated;
    await _storage.saveBudgetLimits(state, _email);
  }

  Future<void> deleteCategory(String name) async {
    final updated = Map<String, double>.from(state);
    updated.remove(name);
    state = updated;
    await _storage.saveBudgetLimits(state, _email);
  }
}
