import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/models/group_model.dart';
import 'package:expense_tracker/models/user_model.dart';
import 'package:expense_tracker/screens/group/groups_screen.dart';
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
  String _selectedCategory = 'Food 🍔';
  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool _showCustomCategoryInput = false;
  String? _selectedGroupId;
  List<String> _splitWithIds = [];

  final List<String> _categories = [
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

    setState(() => _isAnalyzing = true);

    try {
      final result = await receiptService.analyzeReceipt(image);
      if (result != null && mounted) {
        setState(() {
          _amountController.text = (result['amount'] ?? '').toString();
          final category = result['category'] as String?;
          if (category != null) {
            if (_categories.contains(category)) {
              _selectedCategory = category;
              _showCustomCategoryInput = false;
            } else {
              _showCustomCategoryInput = true;
              _customCategoryController.text = category;
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt analyzed successfully!')),
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
    final amount = double.tryParse(_amountController.text) ?? 0;
    final category = _showCustomCategoryInput ? _customCategoryController.text.trim() : _selectedCategory;

    if (user == null || amount <= 0 || category.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final expense = ExpenseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        amount: amount,
        category: category,
        date: DateTime.now(),
        groupId: _selectedGroupId,
        splitWith: _selectedGroupId != null ? (_splitWithIds.isEmpty ? null : _splitWithIds) : null,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      await ref.read(firestoreServiceProvider).addExpense(expense);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
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
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Expense', 
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_isAnalyzing)
                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    onPressed: _scanReceipt, 
                    icon: const Icon(Icons.document_scanner_outlined, color: Colors.blue),
                    tooltip: 'Scan Receipt',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              autofocus: true,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            Text(
              'Category', 
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._categories.map((cat) => ChoiceChip(
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
                decoration: InputDecoration(
                  labelText: 'Custom Category Name',
                  hintText: 'e.g. Cinema 🍿',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Split with Group (Optional)', 
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
            ),
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
                          _splitWithIds = []; // Reset splits
                        });
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
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
            const SizedBox(height: 24),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'What was this for?',
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveExpense,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
