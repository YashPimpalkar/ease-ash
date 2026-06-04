import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Budget Calculations Unit Tests', () {
    test('Calculates balance correctly with starting balance and transaction logs', () {
      const double startingBalance = 5000.0;

      final mockTransactions = [
        {'title': 'Salary', 'amount': 15000.0, 'isExpense': false, 'category': 'Salary'},
        {'title': 'Grocery', 'amount': 1200.0, 'isExpense': true, 'category': 'Food'},
        {'title': 'Gym Fee', 'amount': 1500.0, 'isExpense': true, 'category': 'Gym'},
        {'title': 'Electricity', 'amount': 800.0, 'isExpense': true, 'category': 'Utilities'},
        {'title': 'Refund', 'amount': 300.0, 'isExpense': false, 'category': 'Other'},
      ];

      double income = 0.0;
      double expense = 0.0;

      for (final tx in mockTransactions) {
        final amt = tx['amount'] as double;
        final isExp = tx['isExpense'] as bool;
        if (isExp) {
          expense += amt;
        } else {
          income += amt;
        }
      }

      final finalBalance = startingBalance + income - expense;

      expect(income, equals(15300.0));
      expect(expense, equals(3500.0));
      expect(finalBalance, equals(16800.0));
    });
  });
}
