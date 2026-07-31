import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/budget_provider.dart';

/// 资产统计页面
/// 入口：我的页面 → 「资产统计」按钮
class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(assetsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('资产统计', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: assetsAsync.when(
        data: (data) => _buildContent(data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildContent(AssetsData data) {
    final fmt = NumberFormat('#,##0.00');

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(assetsProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // ===== 总览卡片 =====
          Container(
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
              children: [
                const Text('净资产', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '¥ ${fmt.format(data.netAssets)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _AssetSummaryChip(
                        label: '总资产',
                        amount: data.totalAssets,
                        icon: Icons.account_balance_wallet,
                        color: const Color(0xFFA8E6CF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AssetSummaryChip(
                        label: '总负债',
                        amount: data.totalLiabilities,
                        icon: Icons.credit_card,
                        color: const Color(0xFFFFB3B3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ===== 账户列表 =====
          Row(
            children: [
              const Icon(Icons.credit_card_outlined, size: 18, color: Color(0xFF4A90E2)),
              const SizedBox(width: 6),
              const Text('账户列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${data.accounts.length} 个账户',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (data.accounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: _whiteCard(),
              child: const Center(
                child: Text('暂无账户，请先在「账户管理」中添加', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...data.accounts.map((acc) => _AccountTile(
                  account: acc,
                  onInitialBalanceChanged: () {
                    // 刷新资产数据
                    ref.invalidate(assetsProvider);
                  },
                )),

          const SizedBox(height: 24),

          // ===== 说明 =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _whiteCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    const Text('关于净资产计算', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• 净资产 = 总资产 - 总负债\n'
                  '• 资产余额 = 当前余额（流水累计）\n'
                  '• 初始余额 = 你最初存钱的数额\n'
                  '• 点击账户可设置「初始余额」，用于计算净资产',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.8),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  BoxDecoration _whiteCard() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
    );
  }
}

class _AssetSummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _AssetSummaryChip({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '¥ ${amount.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  final AccountAsset account;
  final VoidCallback onInitialBalanceChanged;

  const _AccountTile({required this.account, required this.onInitialBalanceChanged});

  IconData _accountIcon(String type) {
    switch (type) {
      case 'cash': return Icons.wallet;
      case 'card': return Icons.credit_card;
      case 'credit': return Icons.payment;
      case 'liability': return Icons.money_off;
      default: return Icons.account_balance_wallet;
    }
  }

  Color _accountColor(String type) {
    switch (type) {
      case 'cash': return const Color(0xFF4A90E2);
      case 'card': return const Color(0xFF67B26F);
      case 'credit': return const Color(0xFFFF6B6B);
      case 'liability': return const Color(0xFFE74C3C);
      default: return const Color(0xFF95A5A6);
    }
  }

  String _accountTypeName(String type) {
    switch (type) {
      case 'cash': return '现金';
      case 'card': return '储蓄卡';
      case 'credit': return '信用卡';
      case 'liability': return '负债';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _accountColor(account.type);
    final fmt = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_accountIcon(account.type), color: color, size: 22),
        ),
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _accountTypeName(account.type),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '余额 ',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
                Text(
                  '¥ ${fmt.format(account.balance)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (account.initialBalance > 0) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '初始 ',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                  Text(
                    '¥ ${fmt.format(account.initialBalance)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (account.initialBalance == 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '未设置初始',
                  style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
              onPressed: () => _showEditDialog(context),
            ),
          ],
        ),
        onTap: () => _showEditDialog(context),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(
      text: account.initialBalance > 0 ? account.initialBalance.toStringAsFixed(2) : '',
    );
    final fmt = NumberFormat('#,##0.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('设置初始余额'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '当前余额: ¥ ${fmt.format(account.balance)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Text('初始余额（记得当初存了多少钱）', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: InputDecoration(
                prefixText: '¥ ',
                hintText: '输入初始余额',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final amount = double.tryParse(ctrl.text) ?? 0;
              try {
                final api = ref.read(apiProvider);
                await api.setAccountInitialBalance(account.id, amount);
                onInitialBalanceChanged();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('初始余额已保存 ✅'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
