import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../api/api_service.dart';
import 'category_manage_screen.dart';
import 'account_manage_screen.dart';

class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 用户信息卡片
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: Text('🐂', style: TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.phone?.replaceFirst(RegExp(r'(\d{3})\d{4}(\d{4})'), r'$1****$2') ?? '未登录',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '数据存储于自有NAS',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 功能菜单
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.category_outlined,
                    title: '分类管理',
                    subtitle: '增删支出/收入分类',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManageScreen())),
                  ),
                  _MenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: '账户管理',
                    subtitle: '增删账户',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountManageScreen())),
                  ),
                  _MenuItem(
                    icon: Icons.file_download_outlined,
                    title: '导出CSV',
                    subtitle: '导出账单数据',
                    onTap: () => _showExportDialog(context, ref),
                  ),
                  _MenuItem(
                    icon: Icons.cloud_upload_outlined,
                    title: '导入钱迹数据',
                    subtitle: '从钱迹CSV导入历史账单',
                    onTap: () => _showImportDialog(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 登出
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _showLogoutDialog(context, ref),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('退出登录'),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '小牛记账 v1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出CSV'),
        content: const Text('确定要导出全部账单数据为CSV文件吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiProvider);
                final csv = await api.exportCsv();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('导出成功，请在服务器上查看CSV文件'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入钱迹数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请输入钱迹CSV文件的完整路径：', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '例如: /mnt/user/钱迹备份/xxx.csv',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '支持的格式：钱迹App导出的CSV文件',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                // 先读取文件内容
                final filePath = controller.text.trim();
                final fileContent = await _readFile(filePath, ref);
                // 调用导入API
                final api = ref.read(apiProvider);
                final result = await api.importQianjiCsv(fileContent);
                ref.invalidate(recordsProvider({'limit': 10}));
                ref.invalidate(monthlyStatsProvider((year: DateTime.now().year, month: DateTime.now().month)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('导入成功！共${result['imported']}条，${result['skipped']}条跳过（已有${result['total']}条记录）'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<String> _readFile(String path, WidgetRef ref) async {
    // 通过后端代理读取文件
    final uri = Uri.parse('${baseUrl}/api/file/read').replace(
      queryParameters: {'path': path},
    );
    final res = await http.get(uri, headers: {'x-phone': ref.read(authProvider).phone ?? ''});
    if (res.statusCode == 200) {
      return res.body;
    }
    throw Exception('读取文件失败: ${res.statusCode}');
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4A90E2)),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
