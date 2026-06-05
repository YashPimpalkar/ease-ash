import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/secure_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../budget/domain/transaction_model.dart';

class CategoryRulesScreen extends ConsumerStatefulWidget {
  const CategoryRulesScreen({super.key});

  @override
  ConsumerState<CategoryRulesScreen> createState() => _CategoryRulesScreenState();
}

class _CategoryRulesScreenState extends ConsumerState<CategoryRulesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'all'; // 'all' | 'mapped' | 'unmapped'
  List<String> _uniqueTitles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactionTitles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactionTitles() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final auth = ref.read(authProvider);
      final email = auth.email ?? '';

      // Fetch all transactions to collect unique names
      final txs = await db.isar.transactions
          .filter()
          .userEmailEqualTo(email)
          .findAll();

      final titlesSet = txs.map((tx) => tx.title.trim()).toSet();

      // Also merge any mapped names that might not exist in Isar transactions
      final mappings = ref.read(titleCategoryMappingsProvider);
      for (final key in mappings.keys) {
        // Find if there is a capitalized matching version in the history
        final existingTitle = titlesSet.firstWhere(
          (t) => t.toLowerCase() == key.toLowerCase(),
          orElse: () => key,
        );
        titlesSet.add(existingTitle);
      }

      setState(() {
        _uniqueTitles = titlesSet.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCategoryRule(String title, String newCategory) async {
    final auth = ref.read(authProvider);
    final email = auth.email ?? '';
    final db = ref.read(databaseServiceProvider);

    // 1. Update the local mappings map (Secure Storage)
    if (newCategory == 'None') {
      await ref.read(titleCategoryMappingsProvider.notifier).removeMapping(title);
    } else {
      await ref.read(titleCategoryMappingsProvider.notifier).updateMapping(title, newCategory);
    }

    // 2. Update existing transactions in Isar with this title case-insensitively
    await db.isar.writeTxn(() async {
      final txs = await db.isar.transactions
          .filter()
          .userEmailEqualTo(email)
          .findAll();
      
      final matchedTxs = txs.where((t) => t.title.toLowerCase().trim() == title.toLowerCase().trim()).toList();

      for (final tx in matchedTxs) {
        tx.category = newCategory;
        tx.isSynced = false; // Trigger database sync on next sync
      }
      await db.isar.transactions.putAll(matchedTxs);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated all "$title" transactions to $newCategory', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF00E6FF),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mappings = ref.watch(titleCategoryMappingsProvider);
    final budgetLimits = ref.watch(budgetLimitsProvider);

    // Collect all available categories
    final availableCategories = {
      ...budgetLimits.keys,
      'Salary',
      'Gift',
      'Other',
      'None',
    }.toList();

    // Filter unique titles
    final filteredTitles = _uniqueTitles.where((title) {
      // Search query filter
      if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Tab filter
      final hasMapping = mappings.containsKey(title.toLowerCase().trim());
      if (_activeFilter == 'mapped' && !hasMapping) return false;
      if (_activeFilter == 'unmapped' && hasMapping) return false;

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Categorization Rules'),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E6FF)))
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF131326),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF22223F)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Search transaction names...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),

                    // Filters toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All'),
                          const SizedBox(width: 8),
                          _buildFilterChip('mapped', 'Mapped'),
                          const SizedBox(width: 8),
                          _buildFilterChip('unmapped', 'Unmapped'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Titles rules list
                    Expanded(
                      child: filteredTitles.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No transaction names found matching "$_searchQuery"'
                                    : _activeFilter == 'mapped'
                                        ? 'No mapped category rules yet.'
                                        : 'All transactions are already mapped!',
                                style: const TextStyle(color: Colors.white38, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                              itemCount: filteredTitles.length,
                              itemBuilder: (context, index) {
                                final title = filteredTitles[index];
                                final currentCategory = mappings[title.toLowerCase().trim()] ?? 'None';

                                return Card(
                                  color: const Color(0xFF131326),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: currentCategory != 'None'
                                          ? const Color(0xFF6C63FF).withAlpha(100)
                                          : const Color(0xFF22223F),
                                      width: currentCategory != 'None' ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Left Side: Transaction Title
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Right Side: Category Selector Dropdown
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0E0E1B),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: currentCategory != 'None'
                                                  ? const Color(0xFF00E6FF)
                                                  : Colors.white24,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: currentCategory,
                                              dropdownColor: const Color(0xFF131326),
                                              style: TextStyle(
                                                color: currentCategory != 'None'
                                                    ? const Color(0xFF00E6FF)
                                                    : Colors.white60,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              icon: Icon(
                                                Icons.arrow_drop_down,
                                                color: currentCategory != 'None'
                                                    ? const Color(0xFF00E6FF)
                                                    : Colors.white38,
                                              ),
                                              items: availableCategories.map((cat) {
                                                return DropdownMenuItem(
                                                  value: cat,
                                                  child: Text(cat),
                                                );
                                              }).toList(),
                                              onChanged: (newCat) {
                                                if (newCat != null && newCat != currentCategory) {
                                                  _updateCategoryRule(title, newCat);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _activeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF6C63FF),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white54,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() => _activeFilter = value);
      },
    );
  }
}
