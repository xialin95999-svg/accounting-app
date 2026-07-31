import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../providers/auth_provider.dart';
import 'add_record_screen.dart';
import 'annual_report_screen.dart';
import '../providers/budget_provider.dart';
import 'bill_screen.dart';
import 'mine_screen.dart';

// ==================== 主页面 ====================
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomePage(selectedMonth: _selectedMonth, onMonthChanged: (m) => setState(() => _selectedMonth = m)),
          BillScreen(selectedMonth: _selectedMonth, onMonthChanged: (m) => setState(() => _selectedMonth = m)),
          const MineScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black26,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 26),
            selectedIcon: Icon(Icons.home, size: 26, color: Color(0xFF4A90E2)),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline, size: 26),
            selectedIcon: Icon(Icons.pie_chart, size: 26, color: Color(0xFF4A90E2)),
            label: '账单',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 26),
            selectedIcon: Icon(Icons.person, size: 26, color: Color(0xFF4A90E2)),
            label: '我的',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? _FloatingAddButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRecordScreen()))
                    .then((_) {
                  ref.invalidate(monthlyStatsProvider((year: _selectedMonth.year, month: _selectedMonth.month)));
                  ref.invalidate(recordsProvider({'limit': 10}));
                });
              },
            )
          : null,
    );
  }
}

// ==================== 悬浮记一笔按钮 ====================
class _FloatingAddButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _FloatingAddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF67B26F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}

// ==================== 首页内容 ====================
class _HomePage extends ConsumerWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _HomePage({required this.selectedMonth, required this.onMonthChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthlyStatsProvider((year: selectedMonth.year, month: selectedMonth.month)));
    final recordsAsync = ref.watch(recordsProvider({'limit': 10}));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('小牛记账', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            Text(
              DateFormat('yyyy年M月').format(selectedMonth),
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color(0xFF4A90E2)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) onMonthChanged(DateTime(picked.year, picked.month));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4A90E2),
        onRefresh: () async {
          ref.invalidate(monthlyStatsProvider((year: selectedMonth.year, month: selectedMonth.month)));
          ref.invalidate(recordsProvider({'limit': 10}));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [
            // 余额卡片
            statsAsync.when(
              data: (stats) => _BalanceCard(stats: stats),
              loading: () => const _BalanceCardSkeleton(),
              error: (e, _) => _ErrorCard(msg: e.toString()),
            ),
            const SizedBox(height: 16),
            // 收支概览
            statsAsync.when(
              data: (stats) => _IncomeExpenseRow(stats: stats),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            // 最近记录
            const _SectionTitle(title: '最近记录', icon: Icons.receipt_long_outlined),
            const SizedBox(height: 12),
            recordsAsync.when(
              data: (data) {
                if (data.records.isEmpty) {
                  return _EmptyRecords();
                }
                return _RecordsList(records: data.records);
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => _ErrorCard(msg: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 余额卡片 ====================
class _BalanceCard extends StatelessWidget {
  final MonthlyStats stats;
  const _BalanceCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final balance = (stats.income - stats.expense).toStringAsFixed(2);
    final isPositive = double.parse(balance) >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF6BB3F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本月结余', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            isPositive ? '¥ $balance' : '- ¥ ${balance.replaceFirst('-', '')}',
            style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _IncomeExpenseChip(label: '收入', amount: stats.income, icon: Icons.arrow_downward, color: const Color(0xFFA8E6CF)),
              const SizedBox(width: 12),
              _IncomeExpenseChip(label: '支出', amount: stats.expense, icon: Icons.arrow_upward, color: Color.lerp(const Color(0xFFFFB3B3), Colors.white, 0.3)!),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeExpenseChip extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _IncomeExpenseChip({required this.label, required this.amount, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text('$label ¥${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==================== 收支概览行 ====================
class _IncomeExpenseRow extends StatelessWidget {
  final MonthlyStats stats;
  const _IncomeExpenseRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _QuickStatCard(label: '收入', amount: stats.income, color: const Color(0xFF67B26F), icon: Icons.arrow_downward)),
        const SizedBox(width: 12),
        Expanded(child: _QuickStatCard(label: '支出', amount: stats.expense, color: const Color(0xFFFF6B6B), icon: Icons.arrow_upward)),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _QuickStatCard({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ==================== 区块标题 ====================
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4A90E2)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
      ],
    );
  }
}

// ==================== 空记录状态 ====================
class _EmptyRecords extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(Icons.description, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('还没有记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 4),
          const Text('点击底部 + 记下第一笔吧', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ==================== 记录列表 ====================
class _RecordsList extends StatelessWidget {
  final List<Record> records;
  const _RecordsList({required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: records.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (context, index) {
          final r = records[index];
          return _RecordItem(record: r);
        },
      ),
    );
  }
}

class _RecordItem extends StatelessWidget {
  final Record record;
  const _RecordItem({required this.record});

  IconData _categoryIcon(String cat) {
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

  Color _categoryColor(String cat) {
    final colors = [
      const Color(0xFFFF6B6B), const Color(0xFF4ECDC4), const Color(0xFFFFE66D),
      const Color(0xFF95E1D3), const Color(0xFFF38181), const Color(0xFFAA96DA),
      const Color(0xFF6BB3F8), const Color(0xFF67B26F), const Color(0xFFFF9A76),
    ];
    return colors[cat.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = record.type == 'expense';
    final amount = isExpense ? '-¥${record.amount.toStringAsFixed(2)}' : '+¥${record.amount.toStringAsFixed(2)}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _categoryColor(record.category).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_categoryIcon(record.category), color: _categoryColor(record.category), size: 22),
      ),
      title: Text(record.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        DateFormat('MM/dd HH:mm').format(DateTime.parse(record.date)),
        style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
      ),
      trailing: Text(
        amount,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isExpense ? const Color(0xFFFF6B6B) : const Color(0xFF67B26F),
        ),
      ),
    );
  }
}

// ==================== 骨架屏 ====================
class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 60, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Container(width: 160, height: 36, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(width: 80, height: 28, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20))),
              const SizedBox(width: 12),
              Container(width: 80, height: 28, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20))),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== 错误卡片 ====================
class _ErrorCard extends StatelessWidget {
  final String msg;
  const _ErrorCard({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE0E0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, color: Color(0xFFCC4444)))),
        ],
      ),
    );
  }
}

// ==================== 超支预警横幅 ====================
class _BudgetWarningBanner extends StatelessWidget {
  final BudgetConfig config;
  const _BudgetWarningBanner({required this.config});

  @override
  Widget build(BuildContext context) {
    final spent = config.categories.fold(0.0, (s, c) => s + c.spent);
    final limit = config.monthlyLimit;
    if (limit <= 0) return const SizedBox.shrink();

    final pct = spent / limit;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (pct >= 1.0) {
      bgColor = const Color(0xFFFFE0E0);
      textColor = Colors.red;
      icon = Icons.warning_rounded;
    } else if (pct >= 0.8) {
      bgColor = const Color(0xFFFFF3E0);
      textColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
    } else {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF67B26F);
      icon = Icons.check_circle_outline;
    }

    final overCategories = config.categories.where((c) => c.isOverBudget).toList();
    final mainMsg = pct >= 1.0
        ? '本月支出已达 ¥${spent.toStringAsFixed(0)}/¥${limit.toStringAsFixed(0)}（${(pct * 100).toStringAsFixed(0)}%）'
        : pct >= 0.8
            ? '本月支出已达 ¥${spent.toStringAsFixed(0)}/¥${limit.toStringAsFixed(0)}（${(pct * 100).toStringAsFixed(0)}%）'
            : '本月支出 ¥${spent.toStringAsFixed(0)}/¥${limit.toStringAsFixed(0)}（${(pct * 100).toStringAsFixed(0)}%）';
    final overMsg = overCategories.isNotEmpty
        ? '\n${overCategories.map((c) => '${c.category}已超支¥${(-c.remaining).toStringAsFixed(0)}').join('、')}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mainMsg + overMsg,
              style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
