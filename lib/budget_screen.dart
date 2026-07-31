import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';

/// 预算设置页面
/// 入口：我的页面 → 「预算设置」按钮
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  late BudgetConfig _config;
  bool _isLoading = false;
  bool _isDirty = false;

  final _monthlyController = TextEditingController();
  final _currencyFormat = NumberFormat('#,##0.00');

  @override
  void dispose() {
    _monthlyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetAsync = ref.watch(budgetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('预算设置', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isDirty)
            TextButton(
              onPressed: _isLoading ? null : _saveBudget,
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: budgetAsync.when(
        data: (config) {
          _config = config;
          if (_monthlyController.text.isEmpty && config.monthlyLimit > 0) {
            _monthlyController.text = config.monthlyLimit.toStringAsFixed(0);
          }
          return _buildContent(config);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildContent(BudgetConfig config) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ===== 月度总预算开关 =====
        Container(
          decoration: _cardDecoration(),
          child: SwitchListTile(
            title: const Text('月度预算总开关', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('开启后可设置每月支出上限', style: TextStyle(fontSize: 12, color: Colors.grey)),
            value: config.enabled,
            activeColor: const Color(0xFF4A90E2),
            onChanged: (v) => _updateConfig(config.copyWithEnabled(v)),
          ),
        ),

        const SizedBox(height: 12),

        // ===== 月度总金额输入 =====
        if (config.enabled)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('月度预算总金额', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  '本月已花费 ¥${_currencyFormat.format(_config.categories.fold(0.0, (s, c) => s + c.spent))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _monthlyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    prefixText: '¥ ',
                    prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    hintText: '输入月度预算上限',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  onChanged: (v) {
                    final amount = double.tryParse(v) ?? 0;
                    _updateConfig(config.copyWithMonthlyLimit(amount));
                  },
                ),
                // 进度条
                _buildOverallProgress(config),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // ===== 分类预算列表 =====
        if (config.enabled) ...[
          Row(
            children: [
              const Icon(Icons.category_outlined, size: 18, color: Color(0xFF4A90E2)),
              const SizedBox(width: 6),
              const Text('分类预算', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${config.categories.length} 个分类',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...config.categories.map((cat) => _CategoryBudgetTile(
                category: cat,
                onBudgetChanged: (newBudget) {
                  final idx = _config.categories.indexOf(cat);
                  final updated = List<CategoryBudget>.from(_config.categories);
                  updated[idx] = cat.copyWith(budget: newBudget);
                  _updateConfig(_config.copyWithCategories(updated));
                },
              )),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildOverallProgress(BudgetConfig config) {
    final spent = config.categories.fold(0.0, (s, c) => s + c.spent);
    final limit = config.monthlyLimit;
    if (limit <= 0) return const SizedBox.shrink();
    final pct = (spent / limit).clamp(0.0, 1.5);

    Color barColor;
    if (pct < 0.8) {
      barColor = const Color(0xFF67B26F);
    } else if (pct < 1.0) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(barColor),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已用 ${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: barColor, fontWeight: FontWeight.w600),
            ),
            Text(
              '剩余 ¥${_currencyFormat.format((limit - spent).clamp(0, double.infinity))}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
    );
  }

  void _updateConfig(BudgetConfig newConfig) {
    setState(() {
      _config = newConfig;
      _isDirty = true;
    });
  }

  Future<void> _saveBudget() async {
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(saveBudgetProvider);
      await svc.save(_config.copyWithMonthlyLimit(double.tryParse(_monthlyController.text) ?? 0));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('预算保存成功 ✅'), backgroundColor: Colors.green),
        );
        setState(() => _isDirty = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ===== 分类预算行 =====
class _CategoryBudgetTile extends StatefulWidget {
  final CategoryBudget category;
  final ValueChanged<double> onBudgetChanged;

  const _CategoryBudgetTile({required this.category, required this.onBudgetChanged});

  @override
  State<_CategoryBudgetTile> createState() => _CategoryBudgetTileState();
}

class _CategoryBudgetTileState extends State<_CategoryBudgetTile> {
  bool _expanded = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.category.budget > 0 ? widget.category.budget.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final hasBudget = cat.budget > 0;
    final remaining = cat.remaining;
    final isOver = cat.isOverBudget;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _catColor(cat.category).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(_catEmoji(cat.category), style: const TextStyle(fontSize: 20))),
            ),
            title: Text(cat.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              '已花 ¥${cat.spent.toStringAsFixed(0)}${hasBudget ? ' / 预算 ¥${cat.budget.toStringAsFixed(0)}' : '（未设预算）'}',
              style: TextStyle(fontSize: 12, color: isOver ? Colors.red : Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasBudget)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOver ? Colors.red[50] : const Color(0xFF67B26F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOver
                          ? '超支 ¥${(-remaining).toStringAsFixed(0)}'
                          : '剩 ¥${remaining.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOver ? Colors.red : const Color(0xFF67B26F),
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          // 可折叠的预算编辑区
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text('设置分类月度预算', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          decoration: InputDecoration(
                            prefixText: '¥ ',
                            hintText: '输入预算',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (v) {
                            final amount = double.tryParse(v) ?? 0;
                            widget.onBudgetChanged(amount);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          _ctrl.clear();
                          widget.onBudgetChanged(0);
                        },
                        child: const Text('清除', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _colors = {
    '三餐': Color(0xFFE26F56), '饮料': Color(0xFFF5A623), '交通': Color(0xFF4A90E2),
    '购物': Color(0xFF9B59B6), '娱乐': Color(0xFF1ABC9C), '学习': Color(0xFF3498DB),
    '烟酒': Color(0xFFE74C3C), '医疗': Color(0xFF2ECC71), '住房': Color(0xFF95A5A6),
  };

  Color _catColor(String name) => _colors[name] ?? const Color(0xFFBDC3C7);

  static const _emojis = {
    '三餐': '🍜', '饮料': '☕', '零食': '🍪', '水果': '🍎', '买菜': '🥬',
    '交通': '🚇', '购物': '🛒', '娱乐': '🎮', '游戏': '🎯', '学习': '📚',
    '烟酒': '🚬', '医疗': '💊', '服饰': '👔', '住房': '🏠', '日用品': '🧴',
    '理发': '✂️', '通讯': '📱', '旅行': '✈️', '请客': '🎁', '会员': '⭐',
  };

  String _catEmoji(String name) => _emojis[name] ?? '📦';
}

// ==================== 扩展 BudgetConfig ====================

extension BudgetConfigExt on BudgetConfig {
  BudgetConfig copyWithEnabled(bool v) => BudgetConfig(
        enabled: v,
        monthlyLimit: monthlyLimit,
        categories: categories,
      );

  BudgetConfig copyWithMonthlyLimit(double v) => BudgetConfig(
        enabled: enabled,
        monthlyLimit: v,
        categories: categories,
      );

  BudgetConfig copyWithCategories(List<CategoryBudget> v) => BudgetConfig(
        enabled: enabled,
        monthlyLimit: monthlyLimit,
        categories: v,
      );
}
