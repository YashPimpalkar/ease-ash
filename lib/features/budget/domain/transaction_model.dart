import 'package:isar/isar.dart';

part 'transaction_model.g.dart';

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  late String title;

  String? description;

  late double amount;

  @Index()
  late bool isExpense; // true for expense, false for income

  @Index()
  late String category; // e.g. 'Food', 'Salary', 'Gym', 'Rent'

  @Index()
  late DateTime date;

  late bool isSynced;

  @Index()
  String? userEmail;

  @Index(unique: true, replace: true)
  String? smsRefNo;

  Transaction({
    this.id = Isar.autoIncrement,
    required this.title,
    this.description,
    required this.amount,
    required this.isExpense,
    required this.category,
    required this.date,
    this.isSynced = false,
    this.userEmail,
    this.smsRefNo,
  });
}
