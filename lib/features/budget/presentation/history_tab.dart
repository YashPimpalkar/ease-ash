import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/secure_storage_service.dart';
import '../../../core/services/data_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/transaction_model.dart';
import '../../auth/presentation/auth_provider.dart';

class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  // Search & active filter state
  String _searchQuery = '';
  String _typeFilter = 'all'; // 'all' | 'expense' | 'income'
  String? _categoryFilter; // null = all categories
  DateTime? _startDate;
  DateTime? _endDate;
  bool _filtersExpanded = false;

  // Temporary state while filter panel is open (before Apply)
  String _tempTypeFilter = 'all';
  String? _tempCategoryFilter;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;

  // Pagination
  int _currentPage = 1;

  // Data
  List<Transaction> _allTransactions = [];
  bool _isLoading = true;



  static const _cyan = Color(0xFF00E6FF);
  static const _green = Color(0xFF00E676);
  static const _red = Color(0xFFFF5252);
  static const _purple = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTransactions());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Scroll listener ──────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      _tryLoadMore();
    }
  }

  void _tryLoadMore() {
    final filtered = _applyFilters(_allTransactions);
    if (_currentPage * _pageSize < filtered.length) {
      setState(() => _currentPage++);
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final auth = ref.read(authProvider);
      final email = auth.email ?? '';
      final txs = await db.isar.transactions
          .filter()
          .userEmailEqualTo(email)
          .sortByDateDesc()
          .findAll();
      if (mounted) {
        setState(() {
          _allTransactions = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Filtering logic ───────────────────────────────────────────────────────────

  List<Transaction> _applyFilters(List<Transaction> txs) {
    return txs.where((tx) {
      // Type
      if (_typeFilter == 'expense' && !tx.isExpense) return false;
      if (_typeFilter == 'income' && tx.isExpense) return false;
      // Category
      if (_categoryFilter != null && tx.category != _categoryFilter) return false;
      // Date range
      if (_startDate != null && tx.date.isBefore(_startDate!)) return false;
      if (_endDate != null) {
        final eod = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (tx.date.isAfter(eod)) return false;
      }
      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = tx.title.toLowerCase().contains(q);
        final matchAmt = tx.amount.toStringAsFixed(2).contains(q);
        final matchCat = tx.category.toLowerCase().contains(q);
        final matchDesc = tx.description?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchAmt && !matchCat && !matchDesc) return false;
      }
      return true;
    }).toList();
  }

  // ── Search ────────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
          _currentPage = 1;
        });
      }
    });
  }

  // ── Filter panel actions ──────────────────────────────────────────────────────

  void _applyActiveFilters() {
    setState(() {
      _typeFilter = _tempTypeFilter;
      _categoryFilter = _tempCategoryFilter;
      _startDate = _tempStartDate;
      _endDate = _tempEndDate;
      _currentPage = 1;
      _filtersExpanded = false;
    });
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _typeFilter = 'all';
      _categoryFilter = null;
      _startDate = null;
      _endDate = null;
      _tempTypeFilter = 'all';
      _tempCategoryFilter = null;
      _tempStartDate = null;
      _tempEndDate = null;
      _currentPage = 1;
    });
  }

  bool get _hasActiveFilters =>
      _typeFilter != 'all' ||
      _categoryFilter != null ||
      _startDate != null ||
      _endDate != null ||
      _searchQuery.isNotEmpty;

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Color _typeColor(bool isExpense) => isExpense ? _red : _green;

  IconData _typeIcon(bool isExpense) =>
      isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

  // ── Delete ────────────────────────────────────────────────────────────────────

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
              backgroundColor: _red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Edit sheet ────────────────────────────────────────────────────────────────

  void _showEditSheet(Transaction tx) {
    final titleCtrl = TextEditingController(text: tx.title);
    final descCtrl = TextEditingController(text: tx.description ?? '');
    final amountCtrl = TextEditingController(text: tx.amount.toStringAsFixed(2));
    bool isExpense = tx.isExpense;
    String category = tx.category;
    DateTime date = tx.date;

    final budgetLimits = ref.read(budgetLimitsProvider);
    final expenseCats = budgetLimits.keys.toList();
    if (!expenseCats.contains('Other')) {
      expenseCats.add('Other');
    }
    const incomeCats = ['Salary', 'Gift', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final cats = isExpense ? expenseCats : incomeCats;
          if (!cats.contains(category)) category = cats.first;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
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
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _cyan.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_rounded, color: _cyan, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Edit Transaction',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Type toggle
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Expense')),
                          selected: isExpense,
                          selectedColor: _red,
                          backgroundColor: const Color(0xFF131326),
                          labelStyle: TextStyle(
                            color: isExpense ? Colors.white : Colors.white54,
                            fontWeight: isExpense ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setSheet(() {
                            isExpense = true;
                            category = expenseCats.first;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Income')),
                          selected: !isExpense,
                          selectedColor: _green,
                          backgroundColor: const Color(0xFF131326),
                          labelStyle: TextStyle(
                            color: !isExpense ? Colors.white : Colors.white54,
                            fontWeight: !isExpense ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setSheet(() {
                            isExpense = false;
                            category = incomeCats.first;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Title
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _cyan)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _cyan)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _cyan)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: Colors.white54, size: 16),
                          SizedBox(width: 6),
                          Text('Date:', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) setSheet(() => date = picked);
                        },
                        child: Text(
                          _fmt(date),
                          style: const TextStyle(
                            color: _green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Category
                  const Text('Category', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  DropdownButton<String>(
                    value: category,
                    dropdownColor: const Color(0xFF131326),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    items: cats
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheet(() => category = v);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _red),
                            foregroundColor: _red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final confirm = await _showDeleteDialog(tx.title);
                            if (confirm == true) {
                              final ds = ref.read(dataServiceProvider);
                              await ds.deleteTransaction(tx.id);
                              setState(() => _allTransactions.removeWhere((t) => t.id == tx.id));
                              if (ctx.mounted) {
                                Navigator.pop(ctx); // Close the bottom sheet
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text(
                            'Delete',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                            if (titleCtrl.text.trim().isEmpty || amt <= 0) return;

                            final updated = Transaction(
                              id: tx.id,
                              title: titleCtrl.text.trim(),
                              description: descCtrl.text.trim().isEmpty
                                  ? null
                                  : descCtrl.text.trim(),
                              amount: amt,
                              isExpense: isExpense,
                              category: category,
                              date: date,
                              isSynced: false,
                              userEmail: tx.userEmail,
                              smsRefNo: tx.smsRefNo,
                            );

                            final ds = ref.read(dataServiceProvider);
                            await ds.saveTransaction(updated);

                            // Optimistic local update
                            final idx = _allTransactions.indexWhere((t) => t.id == tx.id);
                            if (idx != -1) {
                              setState(() {
                                _allTransactions[idx] = updated;
                                _allTransactions.sort((a, b) => b.date.compareTo(a.date));
                              });
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Auto-sync when transactions are added/changed via Overview tab
    ref.listen(transactionsStreamProvider, (_, next) {
      next.whenData((txs) {
        if (mounted) setState(() => _allTransactions = txs);
      });
    });

    final filtered = _applyFilters(_allTransactions);
    final displayed = filtered.take(_currentPage * _pageSize).toList();
    final hasMore = (_currentPage * _pageSize) < filtered.length;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Column(
        children: [
          // ── Search bar + Filter button ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF131326),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF22223F)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search name, amount, category...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Filter toggle button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filtersExpanded = !_filtersExpanded;
                      if (_filtersExpanded) {
                        // Sync temp state with active state
                        _tempTypeFilter = _typeFilter;
                        _tempCategoryFilter = _categoryFilter;
                        _tempStartDate = _startDate;
                        _tempEndDate = _endDate;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? _cyan.withAlpha(25)
                          : const Color(0xFF131326),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _hasActiveFilters ? _cyan : const Color(0xFF22223F),
                        width: _hasActiveFilters ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: _hasActiveFilters ? _cyan : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filter',
                          style: TextStyle(
                            color: _hasActiveFilters ? _cyan : Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _cyan,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Animated Filter Panel ─────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _filtersExpanded ? _buildFilterPanel() : const SizedBox.shrink(),
          ),

          // ── Results summary ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                if (_hasActiveFilters)
                  GestureDetector(
                    onTap: _clearAll,
                    child: const Row(
                      children: [
                        Icon(Icons.clear_all_rounded, color: _cyan, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Clear filters',
                          style: TextStyle(color: _cyan, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Transaction list ──────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _cyan),
                  )
                : displayed.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: displayed.length + (hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == displayed.length) {
                            // Loading indicator at the bottom
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: _cyan,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            );
                          }
                          return _buildTile(displayed[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ── Filter Panel widget ───────────────────────────────────────────────────────

  Widget _buildFilterPanel() {
    final budgetLimits = ref.watch(budgetLimitsProvider);
    final allCategories = {
      ...budgetLimits.keys,
      'Salary',
      'Gift',
      'Other',
    }.toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(
        borderClr: _cyan.withAlpha(55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TYPE
          const Text(
            'TYPE',
            style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _filterTypeChip('all', 'All', _purple),
              _filterTypeChip('expense', 'Expense', _red),
              _filterTypeChip('income', 'Income', _green),
            ],
          ),
          const SizedBox(height: 14),

          // CATEGORY
          const Text(
            'CATEGORY',
            style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [null, ...allCategories].map((cat) {
              final sel = _tempCategoryFilter == cat;
              return GestureDetector(
                onTap: () => setState(() => _tempCategoryFilter = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _cyan.withAlpha(35) : const Color(0xFF0E0E1B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? _cyan : const Color(0xFF22223F),
                    ),
                  ),
                  child: Text(
                    cat ?? 'All',
                    style: TextStyle(
                      color: sel ? _cyan : Colors.white54,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // DATE RANGE
          const Text(
            'DATE RANGE',
            style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _datePickerButton(
                  'From',
                  _tempStartDate,
                  (d) => setState(() => _tempStartDate = d),
                  isStart: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→', style: TextStyle(color: Colors.white38, fontSize: 16)),
              ),
              Expanded(
                child: _datePickerButton(
                  'To',
                  _tempEndDate,
                  (d) => setState(() => _tempEndDate = d),
                  isStart: false,
                ),
              ),
              if (_tempStartDate != null || _tempEndDate != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => setState(() {
                    _tempStartDate = null;
                    _tempEndDate = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => setState(() {
                    _tempTypeFilter = 'all';
                    _tempCategoryFilter = null;
                    _tempStartDate = null;
                    _tempEndDate = null;
                  }),
                  child: const Text('Reset', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _applyActiveFilters,
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterTypeChip(String value, String label, Color color) {
    final sel = _tempTypeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      selectedColor: color.withAlpha(190),
      backgroundColor: const Color(0xFF0E0E1B),
      side: BorderSide(color: sel ? color : const Color(0xFF22223F)),
      labelStyle: TextStyle(
        color: sel ? Colors.white : Colors.white54,
        fontSize: 12,
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _tempTypeFilter = value),
    );
  }

  Widget _datePickerButton(
    String hint,
    DateTime? value,
    void Function(DateTime) onPick, {
    required bool isStart,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: isStart
              ? (_tempEndDate ?? DateTime.now())
              : DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E1B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null ? _cyan.withAlpha(120) : const Color(0xFF22223F),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 13),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                value != null ? _fmt(value) : hint,
                style: TextStyle(
                  color: value != null ? Colors.white : Colors.white38,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Transaction tile ──────────────────────────────────────────────────────────

  Widget _buildTile(Transaction tx) {
    return Dismissible(
      key: Key('hist_${tx.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _showDeleteDialog(tx.title),
      onDismissed: (_) async {
        final ds = ref.read(dataServiceProvider);
        await ds.deleteTransaction(tx.id);
        setState(() => _allTransactions.removeWhere((t) => t.id == tx.id));
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: AppTheme.glassCardDecoration(
          borderRadius: BorderRadius.circular(16),
          borderClr: _typeColor(tx.isExpense).withAlpha(28),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showEditSheet(tx),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Type indicator
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _typeColor(tx.isExpense).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _typeIcon(tx.isExpense),
                      color: _typeColor(tx.isExpense),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _purple.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tx.category,
                                style: const TextStyle(
                                  color: _purple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _fmt(tx.date),
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        if (tx.description != null && tx.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              tx.description!,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Amount + edit icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${tx.isExpense ? "−" : "+"} ₹${tx.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _typeColor(tx.isExpense),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _cyan.withAlpha(22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_outlined, color: _cyan, size: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasActiveFilters
                ? Icons.search_off_rounded
                : Icons.receipt_long_outlined,
            color: Colors.white12,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters
                ? 'No transactions match\nyour filters'
                : 'No transactions logged yet',
            style: const TextStyle(color: Colors.white38, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _cyan),
                foregroundColor: _cyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }
}
