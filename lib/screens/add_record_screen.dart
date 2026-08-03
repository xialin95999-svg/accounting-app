import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../providers/auth_provider.dart';

class AddRecordScreen extends ConsumerStatefulWidget {
  const AddRecordScreen({super.key});

  @override
  ConsumerState<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends ConsumerState<AddRecordScreen> {
  final _amountController = TextEditingController();
  final _remarkController = TextEditingController();
  String _type = 'expense';
  Map? _selectedCategory;
  String _selectedAccount = '';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('请输入有效金额');
      return;
    }
    if (_selectedCategory == null) {
      _showError('请选择分类');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiProvider);
      final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate);
      await api.addRecord({
        'type': _type,
        'amount': amount,
        'category': _selectedCategory!['name'],
        'account': _selectedAccount,
        'remark': _remarkController.text,
        'date': dateStr,
      });

      ref.invalidate(monthlyStatsProvider((year: _selectedDate.year, month: _selectedDate.month)));
      ref.invalidate(recordsProvider({'limit': 10}));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记账成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    final categories = _type == 'expense'
        ? categoriesAsync.valueOrNull?.expenseCategories ?? []
        : categoriesAsync.valueOrNull?.incomeCategories ?? [];
    final accounts = accountsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存', style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型切换
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _type = 'expense'; _selectedCategory = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'expense' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '支出',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _type == 'expense' ? const Color(0xFFE26F56) : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _type = 'income'; _selectedCategory = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'income' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '收入',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _type == 'income' ? const Color(0xFF67B26F) : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 金额
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¥', style: TextStyle(fontSize: 32, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '0',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 分类
            const Text('选择分类', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (_) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, childAspectRatio: 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12,
                ),
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  final isSelected = _selectedCategory?['name'] == cat['name'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE3F2FD) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected ? Border.all(color: const Color(0xFF4A90E2), width: 2) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat['icon'] ?? '📦', style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            cat['name'] ?? '',
                            style: TextStyle(fontSize: 11, color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载分类失败: $e'),
            ),
            const SizedBox(height: 20),
            // 日期
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.grey),
              title: const Text('日期'),
              trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate), style: const TextStyle(color: Colors.grey)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate));
                  if (time != null) {
                    setState(() => _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  }
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
            // 账户
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.grey),
              title: const Text('账户'),
              trailing: DropdownButton<String>(
                value: _selectedAccount.isEmpty ? null : _selectedAccount,
                hint: const Text('选择账户'),
                items: accounts.map<DropdownMenuItem<String>>((a) => DropdownMenuItem(
                  value: a['name'], child: Text(a['name'] ?? ''),
                )).toList(),
                onChanged: (v) => setState(() => _selectedAccount = v ?? ''),
                underline: const SizedBox(),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            // 备注
            TextField(
              controller: _remarkController,
              decoration: InputDecoration(
                labelText: '备注（选填）',
                prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
