import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';

class BillScreen extends ConsumerWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const BillScreen({super.key, required this.selectedMonth, required this.onMonthChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthlyStatsProvider((year: selectedMonth.year, month: selectedMonth.month)));
    final expenseStatsAsync = ref.watch(categoryStatsProvider((year: selectedMonth.year, month: selectedMonth.month, type: 'expense')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('月账单', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
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
        onRefresh: () async {
          ref.invalidate(monthlyStatsProvider((year: selectedMonth.year, month: selectedMonth.month)));
          ref.invalidate(categoryStatsProvider((year: selectedMonth.year, month: selectedMonth.month, type: 'expense')));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 月份
              Center(
                child: Text(
                  '${selectedMonth.year}年${selectedMonth.month}月',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              // 收支卡片
              statsAsync.when(
                data: (stats) => _StatsSummary(stats: stats),
                loading: () => const _SkeletonCard(height: 120),
                error: (e, _) => _ErrorBox(msg: e.toString()),
              ),
              const SizedBox(height: 20),
              // 日支出趋势
              statsAsync.when(
                data: (stats) => _DailyChart(daily: stats.daily),
                loading: () => const _SkeletonCard(height: 160),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 20),
              // 分类统计
              const Text('支出分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              expenseStatsAsync.when(
                data: (cats) {
                  if (cats.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('本月暂无支出记录', style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      // 饼图
                      if (cats.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: cats.take(6).toList().asMap().entries.map((e) {
                                final colors = [const Color(0xFF4A90E2), const Color(0xFF67B26F), const Color(0xFFE26F56), const Color(0xFFF5A623), const Color(0xFF9B59B6), const Color(0xFF1ABC9C)];
                                return PieChartSectionData(
                                  value: (e.value['total'] as num).toDouble(),
                                  title: '${e.value['percent']}%',
                                  color: colors[e.key % colors.length],
                                  radius: 60,
                                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // 分类列表
                      ...cats.map((c) => _CategoryRow(category: c)),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorBox(msg: e.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSummary extends StatelessWidget {
  final MonthlyStats stats;

  const _StatsSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF67B26F), Color(0xFF4A90E2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('收入', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('+¥${stats.income.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('支出', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('-¥${stats.expense.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('结余 ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  '¥${stats.balance.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  final List<Map> daily;

  const _DailyChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox();

    final maxVal = daily.map((d) => (d['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('日支出趋势', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  left: const FlTitlesData(show: false),
                  right: const FlTitlesData(show: false),
                  top: const FlTitlesData(show: false),
                  bottom: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          if (val.toInt() >= daily.length) return const Text('');
                          final day = daily[val.toInt()]['day'].toString();
                          return Text(day.substring(5), style: const TextStyle(fontSize: 10, color: Colors.grey));
                        },
                        reservedSize: 22,
                      ),
                    ),
                  ),
                ),
                barGroups: daily.asMap().entries.map((e) {
                  final val = (e.value['total'] as num).toDouble();
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: const Color(0xFF4A90E2),
                        width: daily.length > 15 ? 8 : 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Map category;

  const _CategoryRow({required this.category});

  static const _colors = {
    '三餐': Color(0xFFE26F56), '饮料': Color(0xFFF5A623), '交通': Color(0xFF4A90E2),
    '购物': Color(0xFF9B59B6), '娱乐': Color(0xFF1ABC9C), '学习': Color(0xFF3498DB),
    '烟酒': Color(0xFFE74C3C), '医疗': Color(0xFF2ECC71), '住房': Color(0xFF95A5A6),
  };

  Color _getColor(String name) {
    return _colors[name] ?? const Color(0xFFBDC3C7);
  }

  String _getEmoji(String name) {
    const map = {
      '三餐': '🍜', '饮料': '☕', '零食': '🍪', '水果': '🍎', '买菜': '🥬',
      '交通': '🚇', '购物': '🛒', '娱乐': '🎮', '游戏': '🎯', '学习': '📚',
      '烟酒': '🚬', '医疗': '💊', '服饰': '👔', '住房': '🏠', '日用品': '🧴',
      '理发': '✂️', '通讯': '📱', '旅行': '✈️', '请客': '🎁', '会员': '⭐',
    };
    return map[name] ?? '📦';
  }

  @override
  Widget build(BuildContext context) {
    final name = category['category'] ?? '';
    final total = (category['total'] as num).toDouble();
    final percent = category['percent'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: _getColor(name).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(_getEmoji(name), style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text('$percent%', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(
            '-¥${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE26F56)),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
      child: Text('错误: $msg', style: TextStyle(color: Colors.red[700], fontSize: 13)),
    );
  }
}
