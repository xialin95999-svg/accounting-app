import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class CategoryManageScreen extends ConsumerStatefulWidget {
  const CategoryManageScreen({super.key});

  @override
  ConsumerState<CategoryManageScreen> createState() => _CategoryManageScreenState();
}

class _CategoryManageScreenState extends ConsumerState<CategoryManageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '支出'), Tab(text: '收入')],
        ),
      ),
      body: categoriesAsync.when(
        data: (data) => TabBarView(
          controller: _tabController,
          children: [
            _CategoryList(categories: data.expenseCategories, type: 'expense'),
            _CategoryList(categories: data.incomeCategories, type: 'income'),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedIcon = '📦';

    final emojis = ['🍜', '☕', '🍪', '🍎', '🥬', '🚇', '🛒', '🎮', '🎯', '📚', '🚬', '💊', '👔', '🏠', '🧴', '✂️', '📱', '✈️', '🎁', '⭐', '💰', '🎉', '💵', '🧧', '📦'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新增分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '分类名称', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('选择图标', style: TextStyle(fontSize: 14, color: Colors.grey))),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  children: emojis.map((e) => GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = e),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selectedIcon == e ? const Color(0xFFE3F2FD) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                // Bug#F005 fix: 实时读取当前tab状态
                final selectedType = _tabController.index == 0 ? 'expense' : 'income';
                try {
                  final api = ref.read(apiProvider);
                  await api.addCategory({'name': nameController.text, 'icon': selectedIcon, 'type': selectedType});
                  ref.invalidate(categoriesProvider);
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加失败: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final List categories;
  final String type;

  const _CategoryList({required this.categories, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        return ListTile(
          leading: Text(cat['icon'] ?? '📦', style: const TextStyle(fontSize: 24)),
          title: Text(cat['name'] ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context, ref, cat),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Map cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除"${cat['name']}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Bug#F004 fix: id为空时不允许删除，避免误删
              final id = cat['id']?.toString();
              if (id == null || id.isEmpty) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('删除失败: 分类ID异常'), backgroundColor: Colors.red),
                );
                return;
              }
              try {
                final api = ref.read(apiProvider);
                await api.deleteCategory(id);
                ref.invalidate(categoriesProvider);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
