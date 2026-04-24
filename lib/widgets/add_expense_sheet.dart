import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/models/group_model.dart';
import 'package:expense_tracker/models/user_model.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:expense_tracker/services/receipt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _amountController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _noteController = TextEditingController();
  
  TransactionType _selectedType = TransactionType.expense;
  late String _selectedCategory;
  
  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool _showCustomCategoryInput = false;
  String? _selectedGroupId;
  List<String> _splitWithIds = [];

  // Store multiple items from receipt scan
  List<Map<String, dynamic>> _scannedItems = [];

  final List<String> _expenseCategories = [
    'Food 🍔',
    'Travel ✈️',
    'Shopping 🛍️',
    'Bills 💡',
    'Health 💊',
    'Fuel ⛽',
    'EMI/Loan 🏦',
    'Emergency 🚨',
    'Entertainment 🎬',
    'Education 📚',
  ];

  final List<String> _incomeCategories = [
    'Salary 💰',
    'Bonus 💸',
    'Gift 🎁',
    'Investment 📈',
    'Other 💵',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = _expenseCategories[0];
  }

  List<String> get _currentCategories => 
      _selectedType == TransactionType.expense ? _expenseCategories : _incomeCategories;

  Future<void> _scanReceipt() async {
    final receiptService = ref.read(receiptServiceProvider);
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final image = await receiptService.pickImage(source);
    if (image == null) return;

    setState(() {
      _isAnalyzing = true;
      _scannedItems = [];
    });

    try {
      final results = await receiptService.analyzeReceiptMulti(image);
      if (results != null && results.isNotEmpty && mounted) {
        setState(() {
          _scannedItems = results;
          _selectedType = TransactionType.expense;
          
          // If only one item, fill the controllers as usual
          if (_scannedItems.length == 1) {
            _amountController.text = _scannedItems[0]['amount'].toString();
            final category = _scannedItems[0]['category'] as String;
            if (_expenseCategories.contains(category)) {
              _selectedCategory = category;
              _showCustomCategoryInput = false;
            } else {
              _showCustomCategoryInput = true;
              _customCategoryController.text = category;
            }
          } else {
            // Multiple items: Clear manual inputs to avoid confusion
            _amountController.clear();
            _customCategoryController.clear();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${_scannedItems.length} categories in receipt!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not analyze receipt. Please enter manually.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveExpense() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      if (_scannedItems.length > 1) {
        // Save multiple items from scan
        for (var item in _scannedItems) {
          final expense = ExpenseModel(
            id: DateTime.now().millisecondsSinceEpoch.toString() + item['category'].hashCode.toString(),
            userId: user.uid,
            amount: item['amount'],
            category: item['category'],
            date: DateTime.now(),
            groupId: _selectedGroupId,
            splitWith: _selectedGroupId != null ? (_splitWithIds.isEmpty ? null : _splitWithIds) : null,
            note: _noteController.text.trim().isEmpty ? 'Auto-split from receipt' : _noteController.text.trim(),
            type: TransactionType.expense,
          );
          await ref.read(firestoreServiceProvider).addExpense(expense);
        }
      } else {
        // Save single manual item or single scanned item
        final amountText = _amountController.text.trim();
        final amount = double.tryParse(amountText) ?? 0;
        final category = _showCustomCategoryInput ? _customCategoryController.text.trim() : _selectedCategory;

        if (amountText.isEmpty || amount <= 0 || category.isEmpty) {
          _showError('Please fill in all details correctly');
          setState(() => _isLoading = false);
          return;
        }

        final expense = ExpenseModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.uid,
          amount: amount,
          category: category,
          date: DateTime.now(),
          groupId: _selectedType == TransactionType.expense ? _selectedGroupId : null,
          splitWith: _selectedType == TransactionType.expense && _selectedGroupId != null ? (_splitWithIds.isEmpty ? null : _splitWithIds) : null,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          type: _selectedType,
        );

        await ref.read(firestoreServiceProvider).addExpense(expense);
      }
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authServiceProvider).currentUser;
    final groupsAsync = user != null ? ref.watch(groupsStreamProvider(user.uid)) : const AsyncValue<List<GroupModel>>.loading();
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Transaction', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (_isAnalyzing)
                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(onPressed: _scanReceipt, icon: const Icon(Icons.document_scanner_outlined, color: Colors.blue), tooltip: 'Scan Receipt'),
              ],
            ),
            
            if (_scannedItems.length > 1) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Detected Multiple Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._scannedItems.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['category']),
                          Text('₹${item['amount'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('₹${_scannedItems.fold(0.0, (sum, item) => sum + item['amount']).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 18)),
                      ],
                    ),
                    TextButton(onPressed: () => setState(() => _scannedItems = []), child: const Text('Clear and edit manually', style: TextStyle(color: Colors.red, fontSize: 12))),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(value: TransactionType.expense, label: Text('Expense'), icon: Icon(Icons.remove_circle_outline)),
                  ButtonSegment(value: TransactionType.income, label: Text('Income'), icon: Icon(Icons.add_circle_outline)),
                ],
                selected: {_selectedType},
                onSelectionChanged: (val) {
                  setState(() {
                    _selectedType = val.first;
                    _selectedCategory = _currentCategories[0];
                    _showCustomCategoryInput = false;
                  });
                },
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _amountController,
                autofocus: true,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                decoration: InputDecoration(labelText: 'Amount', prefixText: '₹ ', filled: true, fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2))),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),
              Text('Category', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._currentCategories.map((cat) => ChoiceChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat && !_showCustomCategoryInput,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat;
                            _showCustomCategoryInput = false;
                          });
                        },
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      )),
                  ChoiceChip(
                    label: const Text('+ Custom'),
                    selected: _showCustomCategoryInput,
                    onSelected: (selected) {
                      setState(() {
                        _showCustomCategoryInput = true;
                      });
                    },
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ],
              ),
              if (_showCustomCategoryInput) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customCategoryController,
                  decoration: InputDecoration(labelText: 'Custom Category Name', hintText: 'e.g. Cinema 🍿', filled: true, fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                ),
              ],
            ],
            
            if (_selectedType == TransactionType.expense) ...[
              const SizedBox(height: 24),
              Text('Split with Group (Optional)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) return const Text('No groups available', style: TextStyle(color: Colors.grey));
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedGroupId,
                        hint: const Text('Select Group'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('No Split (Personal)')),
                          ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selectedGroupId = v;
                            _splitWithIds = []; 
                          });
                        },
                        decoration: InputDecoration(filled: true, fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                      ),
                      if (_selectedGroupId != null) ...[
                        const SizedBox(height: 16),
                        _buildMemberSelector(groups.firstWhere((g) => g.id == _selectedGroupId)),
                      ],
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(labelText: 'Note (Optional)', hintText: 'What was this for?', filled: true, fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveExpense,
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSelector(GroupModel group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select members to split with:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: group.members.map((mUid) {
            return FutureBuilder<UserModel?>(
              future: ref.read(firestoreServiceProvider).getUser(mUid).first,
              builder: (context, snapshot) {
                final name = snapshot.data?.name ?? '...';
                final isSelected = _splitWithIds.contains(mUid);
                return FilterChip(
                  label: Text(name, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _splitWithIds.add(mUid);
                      } else {
                        _splitWithIds.remove(mUid);
                      }
                    });
                  },
                );
              },
            );
          }).toList(),
        ),
        if (_splitWithIds.isEmpty)
          const Text('Splitting with everyone by default', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }
}
