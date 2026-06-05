import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readsms/readsms.dart';
import 'package:isar/isar.dart';
import '../database/database_service.dart';
import '../database/secure_storage_service.dart';
import 'data_service.dart';
import '../../features/budget/domain/transaction_model.dart';
import '../../features/auth/presentation/auth_provider.dart';

final smsSyncServiceProvider = Provider<SmsSyncService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  final dataService = ref.watch(dataServiceProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final email = ref.watch(authProvider).email ?? '';
  return SmsSyncService(db, dataService, storage, email);
});

class SmsSyncService {
  final DatabaseService _db;
  final DataService _dataService;
  final SecureStorageService _storage;
  final String _userEmail;
  
  StreamSubscription? _incomingSubscription;
  final _readsms = Readsms();

  // Regex to match: debited by <amount> on date <date> trf to <payee> Refno <refNo>
  static final _debitRegex = RegExp(
    r'debited by (\d+(?:\.\d+)?) on date (\d{2}[a-zA-Z]{3}\d{2}) trf to (.+?) Refno (\d+)',
    caseSensitive: false,
  );

  SmsSyncService(this._db, this._dataService, this._storage, this._userEmail);

  /// Requests SMS permission from the user.
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Checks if SMS permission is granted.
  Future<bool> hasPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Parses the month string (e.g. "Jun") into its 1-indexed number.
  int? _parseMonth(String monthStr) {
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    return months[monthStr.toLowerCase()];
  }

  /// Converts SMS date string (DDMMMYY e.g. "04Jun26") to DateTime.
  DateTime? _parseSmsDate(String dateStr) {
    try {
      if (dateStr.length != 7) return null;
      final day = int.tryParse(dateStr.substring(0, 2));
      final monthStr = dateStr.substring(2, 5);
      final yearLastTwo = int.tryParse(dateStr.substring(5, 7));
      
      if (day == null || yearLastTwo == null) return null;
      final month = _parseMonth(monthStr);
      if (month == null) return null;

      final year = 2000 + yearLastTwo;
      return DateTime(year, month, day, 12, 0, 0);
    } catch (_) {
      return null;
    }
  }

  /// Parses a message body and returns a Transaction if it matches the debit pattern.
  Transaction? _parseMessage(String body, DateTime? fallbackDate, Map<String, String> mappings) {
    final match = _debitRegex.firstMatch(body);
    if (match == null) return null;

    final amountStr = match.group(1);
    final dateStr = match.group(2);
    final payeeStr = match.group(3)?.trim();
    final refNoStr = match.group(4);

    if (amountStr == null || dateStr == null || payeeStr == null || refNoStr == null) return null;

    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount <= 0.0) return null;

    final parsedDate = _parseSmsDate(dateStr) ?? fallbackDate ?? DateTime.now();

    // Map using user-defined category mapping rules, default to 'None'
    final cleanTitle = payeeStr.toLowerCase().trim();
    final mappedCategory = mappings[cleanTitle] ?? 'None';

    return Transaction(
      title: payeeStr,
      description: 'Auto-imported from SMS Ref: $refNoStr',
      amount: amount,
      isExpense: true,
      category: mappedCategory,
      date: parsedDate,
      isSynced: false,
      userEmail: _userEmail,
      smsRefNo: refNoStr,
    );
  }

  /// Scans SMS inbox for matching transactions from the last 30 days.
  /// Returns the number of new transactions successfully synced.
  Future<int> syncInbox() async {
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) return 0;
    }

    // Ensure real-time SMS listener is active once permission is granted
    startListening();

    int importCount = 0;
    try {
      final mappings = await _storage.getTitleCategoryMappings(_userEmail);
      final SmsQuery query = SmsQuery();
      final List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
      );

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      for (final msg in messages) {
        // Only process messages within the last 30 days
        if (msg.date == null || msg.date!.isBefore(thirtyDaysAgo)) continue;

        final body = msg.body;
        if (body == null || body.isEmpty) continue;

        // Parse matching transaction
        final tx = _parseMessage(body, msg.date, mappings);
        if (tx == null || tx.smsRefNo == null) continue;

        // Check for duplicates in Isar
        final existing = await _db.isar.transactions
            .filter()
            .smsRefNoEqualTo(tx.smsRefNo)
            .findFirst();

        if (existing == null) {
          await _dataService.saveTransaction(tx);
          importCount++;
        }
      }
    } catch (e) {
      print('SmsSyncService: Error scanning SMS inbox: $e');
    }
    return importCount;
  }

  /// Start listening for incoming SMS messages.
  Future<void> startListening() async {
    bool granted = await hasPermission();
    if (!granted) {
      granted = await requestPermission();
    }
    if (!granted) {
      print('SmsSyncService: SMS permission not granted. Skipping real-time listener.');
      return;
    }
    
    // Cancel existing subscription if any
    await stopListening();

    try {
      _readsms.read();
      _incomingSubscription = _readsms.smsStream.listen((sms) async {
        print('SmsSyncService: Received SMS: "${sms.body}" from ${sms.sender}');
        final mappings = await _storage.getTitleCategoryMappings(_userEmail);
        final tx = _parseMessage(sms.body, sms.timeReceived, mappings);
        if (tx == null || tx.smsRefNo == null) {
          print('SmsSyncService: Failed to parse SMS or missing RefNo');
          return;
        }

        // Check for duplicates
        final existing = await _db.isar.transactions
            .filter()
            .smsRefNoEqualTo(tx.smsRefNo)
            .findFirst();

        if (existing == null) {
          await _dataService.saveTransaction(tx);
          print('SmsSyncService: Real-time transaction saved: ${tx.title} - ${tx.amount}');
        } else {
          print('SmsSyncService: Transaction with RefNo ${tx.smsRefNo} already exists.');
        }
      });
      print('SmsSyncService: Real-time incoming SMS listener started.');
    } catch (e) {
      print('SmsSyncService: Failed to start SMS listener: $e');
    }
  }

  /// Stop listening for incoming SMS messages.
  Future<void> stopListening() async {
    await _incomingSubscription?.cancel();
    _incomingSubscription = null;
  }
}
