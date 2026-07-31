import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';

/// 年度报表页面
/// 入口：月账单页面 → 年份选择 → 进入年报
class AnnualReportScreen extends ConsumerStatefulWidget {
  final int? initialYear;

  const AnnualReportScreen({super.key, this.initialYear});

  @override
  ConsumerState<AnnualReportScreen> createState() => _AnnualReportScreenState();
}

class _AnnualReportScreenState extends ConsumerState<AnnualReportScreen> {
  late int _selectedYear;
  int? _expandedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(yearlyStatsProvider(_selectedYear));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('年度报告', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ===== 年份切换 =====
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Color(0xFF4A90E2)),
                  onPressed: () => setState(() => _selectedYear--),
                ),
                GestureDetector(
                  onTap: () => _showYearPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_selectedYear 年',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2)),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Color(0xFF4A90E2)),
                  onPressed: _selectedYear < DateTime.now().year
                      ? () => setState(() => _selectedYear++)
                      : null,
                ),
              ],
            ),
          ),

          // ===== 报表内容 =====
          Expanded(
            child: statsAsync.when(
              data: (stats) => _buildReport(stats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(YearlyStats stats) {
    final currencyFmt = NumberFormat('#,##0.00');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(yearlyStatsProvider(_selectedYear));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // ===== 年度汇总卡片 =====
          Container(
            padding: const EdgeInsets.all(20),
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
              children: [
                const Text('年度收支总览', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _YearSummaryItem(
                        label: '年收入',
                        amount: stats.totalIncome,
                        color: const Color(0xFFA8E6CF),
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Expanded(
                      child: _YearSummaryItem(
                        label: '年支出',
                        amount: stats.totalExpense,
                        color: const Color(0xFFFFB3B3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '年结余  ¥ ${currencyFmt.format(stats.balance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ===== 月度趋势折线图 =====
          const _SectionHeader(title: '月度收支趋势', icon: Icons.show_chart),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: _whiteCard(),
            child: _MonthlyTrendChart(monthly: stats.monthly),
          ),

          const SizedBox(height: 24),

          // ===== 支出 Top5 饼图 =====
          if (stats.topCategories.isNotEmpty) ...[
            const _SectionHeader(title: '支出 Top 分类', icon: Icons.pie_chart),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _whiteCard(),
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: stats.topCategories.asMap().entries.map((e) {
                          final colors = [
                            const Color(0xFFFF6B6B), const Color(0xFF4ECDC4),
                            const Color(0xFFFFE66D), const Color(0xFF95E1D3),
                            const Color(0xFFF38181),
                          ];
                          return PieChartSectionData(
                            value: e.value.total,
                            title: e.value.percent > 5 ? '${e.value.percent.toStringAsFixed(0)}%' : '',
                            color: colors[e.key % colors.length],
                            radius: 55,
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Top 分类列表
                  ...stats.topCategories.asMap().entries.map((e) => _TopCategoryRow(
                        rank: e.key + 1,
                        category: e.value,
                        color: [
                          const Color(0xFFFF6B6B), const Color(0xFF4ECDC4),
                          const Color(0xFFFFE66D), const Color(0xFF95E1D3),
                          const Color(0xFFF38181),
                        ][e.key % 5],
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ===== 月度明细列表 =====
          const _SectionHeader(title: '月度明细', icon: Icons.calendar_month),
          const SizedBox(height: 12),
          ...stats.monthly.where((m) => m.income > 0 || m.expense > 0).map((m) => _MonthDetailTile(
                month: m,
                isExpanded: _expandedMonth == m.month,
                onTap: () => setState(() {
                  _expandedMonth = _expandedMonth == m.month ? null : m.month;
                }),
              )),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _showYearPicker(BuildContext context) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择年份', textAlign: TextAlign.center),
        children: List.generate(
          DateTime.now().year - 2019,
          (i) => DateTime.now().year - i,
        ).map((y) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, y),
              child: Center(
                child: Text('$y 年', style: const TextStyle(fontSize: 16)),
              ),
            )).toList(),
      ),
    );
    if (picked != null) {
      setState(() => _selectedYear = picked);
    }
  }

  BoxDecoration _whiteCard() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
    );
  }
}

class _YearSummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _YearSummaryItem({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          '¥ ${amount.toStringAsFixed(0)}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  final List<MonthlyData> monthly;

  const _MonthlyTrendChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxVal = monthly.fold<double>(0, (max, m) => [m.income, m.expense, max].reduce((a, b) => a > b ? a : b));

    return LineChart(LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
          getDrawingHorizontalLine: (val) => FlLine(
            color: Colors.grey[200]!,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                if (val < 1 || val > 12) return const Text('');
                return Text('${val.toInt()}月', style: const TextStyle(fontSize: 10, color: Colors.grey));
              },
              reservedSize: 22,
            ),
          ),
        ),
        lineBarsData: [
          // 支出线（红色）
          LineChartBarData(
            spots: monthly.map((m) => FlSpot(m.month.toDouble(), m.expense)).toList(),
            isCurved: true,
            color: const Color(0xFFFF6B6B),
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFFFF6B6B),
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFFF6B6B).withOpacity(0.08),
            ),
          ),
          // 收入线（绿色）
          LineChartBarData(
            spots: monthly.map((m) => FlSpot(m.month.toDouble(), m.income)).toList(),
            isCurved: true,
            color: const Color(0xFF67B26F),
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF67B26F),
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF67B26F).withOpacity(0.08),
            ),
          ),
        ],
        minY: 0,
      ),
    );
  }
}

class _TopCategoryRow extends StatelessWidget {
  final int rank;
  final CategorySummary category;
  final Color color;

  const _TopCategoryRow({required this.rank, required this.category, required this.color});

  String _emoji(String name) {
    const map = {
      '三餐': '🍜', '饮料': '☕', '零食': '🍪', '水果': '🍎', '买菜': '🥬',
      '交通': '🚇', '购物': '🛒', '娱乐': '🎮', '游戏': '🎯', '学习': '📚',
      '烟酒': '🚬', '医疗': '💊', '服饰': '👔', '住房': '🏠', '日用品': '🧴',
      '理发': '✂️', '通讯': '📱', '旅行': '✈️', '请客': '🎁',
    };
    return map[name] ?? '📦';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(_emoji(category.category), style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(category.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Text(
            '¥${category.total.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              '${category.percent.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthDetailTile extends StatelessWidget {
  final MonthlyData month;
  final bool isExpanded;
  final VoidCallback onTap;

  const _MonthDetailTile({required this.month, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final monthName = '${month.month}月';
    final fmt = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        monthName,
                        style: const TextStyle(
                          color: Color(0xFF4A90E2),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '收入 ¥${fmt.format(month.income)}  支出 ¥${fmt.format(month.expense)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '结余 ¥${fmt.format(month.income - month.expense)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (month.income - month.expense) >= 0 ? const Color(0xFF67B26F) : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4A90E2)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
