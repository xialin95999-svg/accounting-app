import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import 'add_record_screen.dart';
import 'bill_screen.dart';
import 'mine_screen.dart';

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
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomePage(selectedMonth: _selectedMonth, onMonthChanged: (m) => setState(() => _selectedMonth = m)),
          BillScreen(selectedMonth: _selectedMonth, onMonthChanged: (m) => setState(() => _selectedMonth = m)),
          const MineScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF4A90E2),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: '账单'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddRecordScreen()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _HomePage extends ConsumerWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _HomePage({required this.selectedMonth, required this.onMonthChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthlyStatsProvider((year: selectedMonth.year, month: selectedMonth.month)));
    final recordsAsync = ref.watch(recordsProvider({'limit': 10}));

    return Scaffold(
      appBar: AppBar(
        title: const Text('记账本', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialEntryMode: DatePickerEntryMode.calendarOnly,
              );
              if (picked != null) {
                onMonthChanged(DateTime(picked.year, picked.month));
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyStatsProvider((year: selectedMonth.year, month: selectedMonth.month)));
          ref.invalidate(recordsProvider({'limit': 10}));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 月份选择
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedMonth,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) onMonthChanged(DateTime(picked.year, picked.month));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF4A90E2).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${selectedMonth.year}年${selectedMonth.month}月',
                          style: const TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A90E2), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 余额卡片
              statsAsync.when(
                data: (stats) => _BalanceCard(stats: stats),
                loading: () => const _BalanceCardSkeleton(),
                error: (e, _) => _ErrorCard(msg: e.toString()),
              ),
              const SizedBox(height: 16),
              // 最近记录标题
              const Text('最近记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // 最近记录列表
              recordsAsync.when(
                data: (data) {
                  if (data.records.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('还没有记录，点点+记一笔吧', style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.records.length,
                    itemBuilder: (context, i) => _RecordItem(record: data.records[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final MonthlyStats stats;

  const _BalanceCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isPositive = stats.balance >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF67B26F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本月结余', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '¥${stats.balance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('收入', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('+¥${stats.income.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('支出', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('-¥${stats.expense.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, height: 160,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String msg;
  const _ErrorCard({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16)),
      child: Text('错误: $msg', style: TextStyle(color: Colors.red[700])),
    );
  }
}

class _RecordItem extends StatelessWidget {
  final Map record;
  const _RecordItem({required this.record});

  @override
  Widget build(BuildContext context) {
    final isExpense = record['type'] == 'expense';
    final amount = (record['amount'] as num).toDouble();
    final date = DateTime.parse(record['date']);
    final timeStr = DateFormat('MM/dd HH:mm').format(date);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(_getCategoryEmoji(record['category'] ?? ''), style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record['category'] ?? '未知', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isExpense ? const Color(0xFFE26F56) : const Color(0xFF67B26F),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    const map = {
      '三餐': '🍜', '饮料': '☕', '零食': '🍪', '水果': '🍎', '买菜': '🥬',
      '交通': '🚇', '购物': '🛒', '娱乐': '🎮', '游戏': '🎯', '学习': '📚',
      '烟酒': '🚬', '医疗': '💊', '服饰': '👔', '住房': '🏠', '日用品': '🧴',
      '理发': '✂️', '通讯': '📱', '旅行': '✈️', '请客': '🎁', '会员': '⭐',
      '工资': '💰', '奖金': '🎉', '收款': '💵', '红包': '🧧', '投资': '📈',
    };
    return map[category] ?? '📦';
  }
}
