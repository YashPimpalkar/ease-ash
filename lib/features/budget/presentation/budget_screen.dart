import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/secure_storage_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/data_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/transaction_model.dart';
import '../../auth/presentation/auth_provider.dart';
import 'history_tab.dart';
import '../../../core/services/sms_sync_service.dart';


class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  // AI Coach state
  String _aiFeedback = '';
  bool _isAiLoading = false;

  // SMS Sync state
  bool _isSmsSyncing = false;

  Future<void> _syncTransactionsFromSms() async {
    setState(() => _isSmsSyncing = true);
    try {
      final syncService = ref.read(smsSyncServiceProvider);
      final count = await syncService.syncInbox();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF131326),
            content: Text(
              count > 0 
                  ? 'Successfully imported $count new transaction(s)!' 
                  : 'All transactions are up to date.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF5252),
            content: Text('Failed to sync SMS: $e', style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSmsSyncing = false);
      }
    }
  }

  Widget _buildSmsSyncButton(BuildContext context) {
    return InkWell(
      onTap: _isSmsSyncing ? null : _syncTransactionsFromSms,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00E6FF).withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00E6FF).withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isSmsSyncing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E6FF),
                      strokeWidth: 1.5,
                    ),
                  )
                : const Icon(
                    Icons.sync_rounded,
                    color: Color(0xFF00E6FF),
                    size: 14,
                  ),
            const SizedBox(width: 4),
            Text(
              _isSmsSyncing ? 'Syncing...' : 'Sync SMS',
              style: const TextStyle(
                color: Color(0xFF00E6FF),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTransaction(
    String title,
    String? description,
    double amount,
    bool isExpense,
    String category,
    DateTime date,
  ) async {
    final email = ref.read(authProvider).email ?? '';
    final tx = Transaction(
      title: title.trim(),
      description: description?.trim(),
      amount: amount,
      isExpense: isExpense,
      category: category,
      date: date,
      isSynced: false,
      userEmail: email,
    );

    final dataService = ref.read(dataServiceProvider);
    await dataService.saveTransaction(tx);
  }

  Future<void> _deleteTransaction(int id) async {
    final dataService = ref.read(dataServiceProvider);
    await dataService.deleteTransaction(id);
  }

  Future<bool?> _showDeleteDialog(String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131326),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "$title"?\nThis cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
    
    final budgetLimits = ref.read(budgetLimitsProvider);
    final expenseCategories = budgetLimits.keys.toList();
    if (!expenseCategories.contains('Other')) {
      expenseCategories.add('Other');
    }
    const incomeCategories = ['Salary', 'Gift', 'Other'];

    String selectedCategory = expenseCategories.contains('Food') ? 'Food' : expenseCategories.first;
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
                                if (!expenseCategories.contains(selectedCategory)) {
                                  selectedCategory = expenseCategories.first;
                                }
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
                          items: (isExpense ? expenseCategories : incomeCategories)
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

  // --- Budget Category CRUD Dialogs ---

  void _showEditCategoryDialog(String oldName, double oldAmount) {
    final nameController = TextEditingController(text: oldName);
    final amountController = TextEditingController(text: oldAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131326),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Category', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Budget Limit (₹)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E6FF),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final newName = nameController.text.trim();
                final newAmount = double.tryParse(amountController.text) ?? oldAmount;
                if (newName.isNotEmpty) {
                  ref.read(budgetLimitsProvider.notifier).updateCategory(oldName, newName, newAmount);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCategoryDialog(String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131326),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Category', style: TextStyle(color: Colors.white)),
          content: Text(
            'Remove "$name" from your budget goals?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                ref.read(budgetLimitsProvider.notifier).deleteCategory(name);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131326),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Category', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Category Name',
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
                  labelText: 'Budget Limit (₹)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (name.isNotEmpty && amount > 0) {
                  ref.read(budgetLimitsProvider.notifier).addCategory(name, amount);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
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
    final startingBalanceDate = ref.watch(startingBalanceDateProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final budgetLimits = ref.watch(budgetLimitsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Text(
                    'Budget Tracker',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Tab bar ────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131326),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF22223F)),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(
                        iconMargin: EdgeInsets.only(bottom: 2),
                        icon: Icon(Icons.pie_chart_outline_rounded, size: 16),
                        text: 'Overview',
                      ),
                      Tab(
                        iconMargin: EdgeInsets.only(bottom: 2),
                        icon: Icon(Icons.history_rounded, size: 16),
                        text: 'History',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // ── Tab views ──────────────────────────────────
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOverviewTab(startingBalance, startingBalanceDate, transactionsAsync, budgetLimits),
                      const HistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'budget_fab',
          backgroundColor: const Color(0xFF00E676),
          onPressed: _showAddTransactionSheet,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    double startingBalance,
    DateTime startingBalanceDate,
    AsyncValue<List<Transaction>> transactionsAsync,
    Map<String, double> budgetLimits,
  ) {
    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00E6FF))),
      error: (err, stack) =>
          Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      data: (transactions) {
        // Filter transactions to ignore those before startingBalanceDate
        final filteredTransactions = transactions.where((tx) => !tx.date.isBefore(startingBalanceDate)).toList();

        // 1. Calculate totals
        double totalIncome = 0.0;
        double totalExpense = 0.0;
        Map<String, double> categoryExpenses = {};

        for (final tx in filteredTransactions) {
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
              titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          );
          colorIndex++;
        });

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 12),

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL BANK BALANCE',
                        style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5),
                      ),
                      _buildSmsSyncButton(context),
                    ],
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
                             : () => _getAiCoachFeedback(
                                currentBalance, totalIncome, totalExpense, filteredTransactions),
                        icon: _isAiLoading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 1.5),
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
                          ? const Text('AI Coach is reviewing your spending logs...',
                              style: TextStyle(color: Colors.white60))
                          : Text(_aiFeedback,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13, height: 1.4)),
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
                                      color: colors[
                                          colors.indexOf(const Color(0xFF6C63FF)) %
                                              colors.length],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$cat: ₹${amt.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11),
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

            // Category Budget Goals — editable & deletable
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Budget Goals',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E676), size: 22),
                  tooltip: 'Add Category',
                  onPressed: _showAddCategoryDialog,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCardDecoration(),
              child: Column(
                children: [
                  ...budgetLimits.keys.map((category) {
                    final spent = categoryExpenses[category] ?? 0.0;
                    final limit = budgetLimits[category]!;
                    final double percent = spent / limit;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(category,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              Text(
                                '₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: percent >= 1.0 ? Colors.redAccent : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _showEditCategoryDialog(category, limit),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.edit_outlined,
                                      color: Color(0xFF00E6FF), size: 16),
                                ),
                              ),
                              InkWell(
                                onTap: () => _showDeleteCategoryDialog(category),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.delete_outline,
                                      color: Color(0xFFFF5252), size: 16),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _getWarningRingColor(percent)),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Transactions (latest 10)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                if (filteredTransactions.length > 10)
                  const Text(
                    'See all in History →',
                    style: TextStyle(color: Color(0xFF00E6FF), fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            filteredTransactions.isEmpty
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
                    itemCount: filteredTransactions.length > 10 ? 10 : filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = filteredTransactions[index];
                      return Dismissible(
                        key: Key('overview_${tx.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _showDeleteDialog(tx.title),
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
                                color: tx.isExpense
                                    ? const Color(0xFFFF5252)
                                    : const Color(0xFF00E676),
                              ),
                            ),
                            title: Text(tx.title,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${tx.category} • ${tx.date.day}/${tx.date.month}/${tx.date.year}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: Text(
                              '${tx.isExpense ? "-" : "+"} ₹${tx.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: tx.isExpense
                                    ? const Color(0xFFFF5252)
                                    : const Color(0xFF00E676),
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
    );
  }
}
