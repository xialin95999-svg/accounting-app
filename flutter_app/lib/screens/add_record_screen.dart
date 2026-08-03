import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';



// ==================== 记一笔主页面 ====================
class AddRecordScreen extends ConsumerStatefulWidget {
  const AddRecordScreen({super.key});

  @override
  ConsumerState<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends ConsumerState<AddRecordScreen> {
  String _type = 'expense';
  final _amountController = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  final _remarkController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  IconData _catIcon(String cat) {
    final map = {
      '餐饮': Icons.restaurant, '三餐': Icons.restaurant, '交通': Icons.directions_bus,
      '购物': Icons.shopping_bag, '娱乐': Icons.sports_esports, '医疗': Icons.medical_services,
      '教育': Icons.school, '工资': Icons.work, '奖金': Icons.card_giftcard,
      '股票': Icons.show_chart, '房租': Icons.home, '水果': Icons.apple,
      '零食': Icons.cookie, '饮料': Icons.local_cafe, '运动': Icons.fitness_center,
      '美容': Icons.spa, '通讯': Icons.phone_android, '日用品': Icons.cleaning_services,
      '社交': Icons.people, '旅行': Icons.flight, '宠物': Icons.pets,
    };
    return map[cat] ?? Icons.category;
  }

  Color _catColor(String cat) {
    final colors = [
      const Color(0xFFFF6B6B), const Color(0xFF4ECDC4), const Color(0xFFFFE66D),
      const Color(0xFF95E1D3), const Color(0xFFF38181), const Color(0xFFAA96DA),
      const Color(0xFF6BB3F8), const Color(0xFF67B26F), const Color(0xFFFF9A76),
    ];
    return colors[cat.hashCode.abs() % colors.length];
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      _showMsg('请输入正确金额');
      return;
    }
    if (_selectedCategory == null) {
      _showMsg('请选择分类');
      return;
    }
    final amount = double.parse(amountText);
    if (amount <= 0) {
      _showMsg('金额必须大于0');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiProvider);
      await api.addRecord({
        'type': _type,
        'amount': amount,
        'category': _selectedCategory!,
        'remark': _remarkController.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      });
      // Bug#F003 fix: pop 前主动 invalidate，避免 IndexedStack 缓存导致首页不刷新
      ref.invalidate(recordsProvider({'limit': 10}));
      ref.invalidate(monthlyStatsProvider((year: DateTime.now().year, month: DateTime.now().month)));
      if (mounted) {
        Navigator.pop(context);
        _showMsg('记好了 ✅', isSuccess: true);
      }
    } catch (e) {
      if (mounted) _showMsg('保存失败：$e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMsg(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? const Color(0xFF67B26F) : const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final catsData = catsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('记一笔', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型切换
            _TypeToggle(type: _type, onChanged: (t) {
              setState(() {
                _type = t;
                _selectedCategory = null;
              });
            }),
            const SizedBox(height: 20),

            // 金额输入
            _AmountInput(controller: _amountController),
            const SizedBox(height: 20),

            // 分类网格
            const _SectionLabel(label: '选择分类'),
            const SizedBox(height: 10),
            if (catsData != null)
              _CategoryGrid(
                categories: _type == 'expense' ? catsData.expenseCategories : catsData.incomeCategories,
                selected: _selectedCategory,
                onSelected: (c) => setState(() => _selectedCategory = c),
                catColor: _catColor,
              ),

            const SizedBox(height: 20),

            // 日期选择
            _SectionLabel(label: '日期'),
            const SizedBox(height: 10),
            _DateSelector(
              selectedDate: _selectedDate,
              onChanged: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 20),

            // 备注
            _SectionLabel(label: '备注（选填）'),
            const SizedBox(height: 10),
            _RemarkInput(controller: _remarkController),
            const SizedBox(height: 32),

            // 保存按钮
            _SaveButton(isSubmitting: _isSubmitting, onPressed: _submit),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ==================== 类型切换 ====================
class _TypeToggle extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;
  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('expense'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: type == 'expense' ? const Color(0xFFFF6B6B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '支出',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: type == 'expense' ? Colors.white : const Color(0xFF888888),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('income'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: type == 'income' ? const Color(0xFF67B26F) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '收入',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: type == 'income' ? Colors.white : const Color(0xFF888888),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 金额输入 ====================
class _AmountInput extends StatelessWidget {
  final TextEditingController controller;
  const _AmountInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text('¥', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
              decoration: const InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFFDDDDDD)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 分类网格 ====================
class _CategoryGrid extends StatelessWidget {
  final List<Map> categories;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Color Function(String) catColor;
  const _CategoryGrid({required this.categories, required this.selected, required this.onSelected, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final name = cat['name'] as String? ?? '';
        final icon = cat['icon'] as String? ?? '📦';
        final isSel = name == selected;
        final color = catColor(name);
        return GestureDetector(
          onTap: () => onSelected(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSel ? color.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSel ? color : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSel ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6)] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(name, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? color : const Color(0xFF555555)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== 日期选择 ====================
class _DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;
  const _DateSelector({required this.selectedDate, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF4A90E2)),
            const SizedBox(width: 10),
            Text(DateFormat('yyyy年MM月dd日').format(selectedDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}

// ==================== 备注输入 ====================
class _RemarkInput extends StatelessWidget {
  final TextEditingController controller;
  const _RemarkInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        maxLength: 50,
        style: const TextStyle(fontSize: 15),
        decoration: const InputDecoration(
          hintText: '例如：牛肉面加卤蛋',
          hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          counterText: '',
        ),
      ),
    );
  }
}

// ==================== 保存按钮 ====================
class _SaveButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onPressed;
  const _SaveButton({required this.isSubmitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF4A90E2).withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isSubmitting
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('保存', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ==================== 区块标题 ====================
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF888888)));
  }
}
