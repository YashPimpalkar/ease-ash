import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/secure_storage_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/transaction_model.dart';
import 'package:isar/isar.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  // AI Coach state
  String _aiFeedback = '';
  bool _isAiLoading = false;

  // Category Budget Limits
  final Map<String, double> _budgetLimits = {
    'Food': 5000.0,
    'Entertainment': 3000.0,
    'Utilities': 8000.0,
    'Rent': 15000.0,
    'Gym': 2000.0,
    'Transport': 3000.0,
    'Other': 4000.0,
  };

  Future<void> _addTransaction(
    String title,
    String? description,
    double amount,
    bool isExpense,
    String category,
    DateTime date,
  ) async {
    final db = ref.read(databaseServiceProvider);
    final tx = Transaction(
      title: title.trim(),
      description: description?.trim(),
      amount: amount,
      isExpense: isExpense,
      category: category,
      date: date,
      isSynced: false,
    );

    await db.isar.writeTxn(() async {
      await db.isar.transactions.put(tx);
    });
  }

  Future<void> _deleteTransaction(int id) async {
    final db = ref.read(databaseServiceProvider);
    await db.isar.writeTxn(() async {
      await db.isar.transactions.delete(id);
    });
  }

  Future<void> _getAiCoachFeedback(double currentBal, double income, double expense, List<Transaction> transactions) async {
    setState(() {
      _isAiLoading = true;
      _aiFeedback = '';
    });

    final aiService = ref.read(aiServiceProvider);
    
    // Format top 10 transactions
    final recentSummary = transactions.take(10).map((t) => {
      'title': t.title,
      'category': t.category,
      'amount': t.amount,
      'isExpense': t.isExpense,
      'date': t.date,
    }).toList();

    try {
      final feedback = await aiService.getBudgetCoachFeedback(
        currentBalance: currentBal,
        incomeTotal: income,
        expenseTotal: expense,
        transactionsSummary: recentSummary,
      );
      setState(() {
        _aiFeedback = feedback;
      });
    } catch (e) {
      setState(() {
        _aiFeedback = 'Unable to get insights: $e';
      });
    } finally {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  void _showAddTransactionSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController();
    bool isExpense = true;
    String selectedCategory = 'Food';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Log Transaction',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Expense')),
                            selected: isExpense,
                            selectedColor: const Color(0xFFFF5252),
                            labelStyle: TextStyle(color: isExpense ? Colors.black : Colors.white),
                            onSelected: (val) {
                              setModalState(() {
                                isExpense = true;
                                if (selectedCategory == 'Salary') selectedCategory = 'Food';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Income')),
                            selected: !isExpense,
                            selectedColor: const Color(0xFF00E676),
                            labelStyle: TextStyle(color: !isExpense ? Colors.black : Colors.white),
                            onSelected: (val) {
                              setModalState(() {
                                isExpense = false;
                                selectedCategory = 'Salary';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Date:', style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        DropdownButton<String>(
                          value: selectedCategory,
                          dropdownColor: const Color(0xFF131326),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: (isExpense
                                  ? ['Food', 'Gym', 'Entertainment', 'Utilities', 'Rent', 'Transport', 'Other']
                                  : ['Salary', 'Gift', 'Other'])
                              .map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedCategory = val);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          final amt = double.tryParse(amountController.text) ?? 0.0;
                          if (titleController.text.isNotEmpty && amt > 0.0) {
                            _addTransaction(
                              titleController.text,
                              descController.text.isEmpty ? null : descController.text,
                              amt,
                              isExpense,
                              selectedCategory,
                              selectedDate,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Save Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Visual warning ring color for budget
  Color _getWarningRingColor(double percent) {
    if (percent >= 1.0) {
      return const Color(0xFFFF5252); // Red (Exceeded)
    } else if (percent >= 0.8) {
      return const Color(0xFFFF8A00); // Yellow/Orange (Warning)
    }
    return const Color(0xFF00E676); // Green (Good)
  }

  @override
  Widget build(BuildContext context) {
    final startingBalance = ref.watch(startingBalanceProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00E6FF))),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (transactions) {
              // 1. Calculate totals
              double totalIncome = 0.0;
              double totalExpense = 0.0;
              Map<String, double> categoryExpenses = {};

              for (final tx in transactions) {
                if (tx.isExpense) {
                  totalExpense += tx.amount;
                  categoryExpenses[tx.category] = (categoryExpenses[tx.category] ?? 0.0) + tx.amount;
                } else {
                  totalIncome += tx.amount;
                }
              }

              final double currentBalance = startingBalance + totalIncome - totalExpense;

              // 2. Prepare fl_chart Pie Chart sections
              final List<PieChartSectionData> pieSections = [];
              final List<Color> colors = [
                const Color(0xFF6C63FF),
                const Color(0xFF00E6FF),
                const Color(0xFFFF5252),
                const Color(0xFFFF8A00),
                const Color(0xFF00E676),
                const Color(0xFFFFC107),
                const Color(0xFFE040FB),
              ];

              int colorIndex = 0;
              categoryExpenses.forEach((category, amount) {
                final double percent = totalExpense > 0 ? (amount / totalExpense) * 100 : 0;
                pieSections.add(
                  PieChartSectionData(
                    color: colors[colorIndex % colors.length],
                    value: amount,
                    title: '${percent.toStringAsFixed(0)}%',
                    radius: 40,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                );
                colorIndex++;
              });

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      'Budget Tracker',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),

                  // Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.glassCardDecoration(
                      borderClr: const Color(0xFF00E6FF).withAlpha(40),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL BANK BALANCE',
                          style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹ ${currentBalance.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward, color: Color(0xFF00E676), size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '₹${totalIncome.toStringAsFixed(0)} Income',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 24),
                            const Icon(Icons.arrow_downward, color: Color(0xFFFF5252), size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '₹${totalExpense.toStringAsFixed(0)} Expense',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // AI Budget Coach Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCardDecoration(
                      borderClr: const Color(0xFF6C63FF).withAlpha(40),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'AI BUDGET COACH',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: _isAiLoading
                                  ? null
                                  : () => _getAiCoachFeedback(currentBalance, totalIncome, totalExpense, transactions),
                              icon: _isAiLoading
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                                    )
                                  : const Icon(Icons.psychology, size: 16),
                              label: const Text('Get Advice', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        if (_aiFeedback.isNotEmpty || _isAiLoading) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF07070F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _isAiLoading
                                ? const Text('AI Coach is reviewing your spending logs...', style: TextStyle(color: Colors.white60))
                                : Text(_aiFeedback, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // fl_chart Analytics
                  if (totalExpense > 0) ...[
                    Text(
                      'Spending by Category',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCardDecoration(),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                sections: pieSections,
                                centerSpaceRadius: 40,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: categoryExpenses.keys.map((cat) {
                                  final amt = categoryExpenses[cat]!;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colors[colors.indexOf(const Color(0xFF6C63FF)) % colors.length], // Dummy index fallback
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '$cat: ₹${amt.toStringAsFixed(0)}',
                                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Category Budget goals progress bars
                  Text(
                    'Monthly Budget Goals',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCardDecoration(),
                    child: Column(
                      children: _budgetLimits.keys.map((category) {
                        final spent = categoryExpenses[category] ?? 0.0;
                        final limit = _budgetLimits[category]!;
                        final double percent = spent / limit;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text(
                                    '₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: percent >= 1.0 ? Colors.redAccent : Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: percent > 1.0 ? 1.0 : percent,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(_getWarningRingColor(percent)),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Transactions
                  Text(
                    'Recent Transactions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  transactions.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppTheme.glassCardDecoration(),
                          child: const Center(
                            child: Text(
                              'No transactions logged yet.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            return Dismissible(
                              key: Key(tx.id.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (dir) => _deleteTransaction(tx.id),
                              child: Card(
                                color: const Color(0xFF131326),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: tx.isExpense
                                        ? const Color(0xFFFF5252).withAlpha(40)
                                        : const Color(0xFF00E676).withAlpha(40),
                                    child: Icon(
                                      tx.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: tx.isExpense ? const Color(0xFFFF5252) : const Color(0xFF00E676),
                                    ),
                                  ),
                                  title: Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${tx.category} • ${tx.date.day}/${tx.date.month}/${tx.date.year}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  trailing: Text(
                                    '${tx.isExpense ? "-" : "+"} ₹${tx.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: tx.isExpense ? const Color(0xFFFF5252) : const Color(0xFF00E676),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E676),
        onPressed: _showAddTransactionSheet,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
