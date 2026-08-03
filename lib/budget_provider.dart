import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';
import 'auth_provider.dart';

// ==================== 预算数据模型 ====================

class BudgetConfig {
  final bool enabled; // 总开关
  final double monthlyLimit; // 月度总预算
  final List<CategoryBudget> categories; // 分类预算
  BudgetConfig({
    this.enabled = false,
    this.monthlyLimit = 0,
    this.categories = const [],
  });

  factory BudgetConfig.fromJson(Map<String, dynamic> json) {
    return BudgetConfig(
      enabled: json['enabled'] ?? false,
      monthlyLimit: (json['monthly_limit'] as num?)?.toDouble() ?? 0,
      categories: (json['categories'] as List?)
              ?.map((c) => CategoryBudget.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'monthly_limit': monthlyLimit,
        'categories': categories.map((c) => c.toJson()).toList(),
      };
}

class CategoryBudget {
  final String category;
  final double budget; // 预算金额
  final double spent; // 当月已花费
  CategoryBudget({
    required this.category,
    this.budget = 0,
    this.spent = 0,
  });

  double get remaining => budget - spent;
  bool get isOverBudget => spent > budget && budget > 0;

  factory CategoryBudget.fromJson(Map<String, dynamic> json) {
    return CategoryBudget(
      category: json['category'] ?? '',
      budget: (json['budget'] as num?)?.toDouble() ?? 0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'budget': budget,
        'spent': spent,
      };

  CategoryBudget copyWith({double? budget, double? spent}) {
    return CategoryBudget(
      category: category,
      budget: budget ?? this.budget,
      spent: spent ?? this.spent,
    );
  }
}

// ==================== 预算 Provider ====================

final budgetProvider = FutureProvider<BudgetConfig>((ref) async {
  final api = ref.watch(apiProvider);
  final res = await api.getBudget();
  return BudgetConfig.fromJson(res['budget'] ?? {});
});

final saveBudgetProvider = Provider((ref) {
  return BudgetService(ref);
});

class BudgetService {
  final Ref _ref;
  BudgetService(this._ref);

  Future<void> save(BudgetConfig config) async {
    final api = _ref.read(apiProvider);
    await api.saveBudget(config.toJson());
    _ref.invalidate(budgetProvider);
  }
}

// ==================== 资产统计 Provider ====================

class AssetsData {
  final double totalAssets; // 总资产
  final double totalLiabilities; // 总负债
  final double netAssets; // 净资产
  final List<AccountAsset> accounts; // 账户列表

  AssetsData({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netAssets,
    required this.accounts,
  });

  factory AssetsData.fromJson(Map<String, dynamic> json) {
    return AssetsData(
      totalAssets: (json['total_assets'] as num?)?.toDouble() ?? 0,
      totalLiabilities: (json['total_liabilities'] as num?)?.toDouble() ?? 0,
      netAssets: (json['net_assets'] as num?)?.toDouble() ?? 0,
      accounts: (json['accounts'] as List?)
              ?.map((a) => AccountAsset.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AccountAsset {
  final String id;
  final String name;
  final String type; // cash/card/credit/liability
  final double balance; // 当前余额
  final double initialBalance; // 初始余额

  AccountAsset({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.initialBalance,
  });

  double get currentValue {
    if (type == 'liability') {
      return -(initialBalance - balance).abs();
    }
    return balance;
  }

  factory AccountAsset.fromJson(Map<String, dynamic> json) {
    return AccountAsset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'cash',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

final assetsProvider = FutureProvider<AssetsData>((ref) async {
  final api = ref.watch(apiProvider);
  final res = await api.getAssets();
  return AssetsData.fromJson(Map<String,dynamic>.from(res));
});

// ==================== 年度报表 Provider ====================

class YearlyStats {
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final List<MonthlyData> monthly; // 每月收支
  final List<CategorySummary> topCategories; // 支出 Top 分类

  YearlyStats({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.monthly,
    required this.topCategories,
  });

  factory YearlyStats.fromJson(Map<String, dynamic> json) {
    return YearlyStats(
      year: json['year'] ?? DateTime.now().year,
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0,
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      monthly: (json['monthly'] as List?)
              ?.map((m) => MonthlyData.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      topCategories: (json['top_categories'] as List?)
              ?.map((c) => CategorySummary.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MonthlyData {
  final int month;
  final double income;
  final double expense;
  MonthlyData({required this.month, required this.income, required this.expense});

  factory MonthlyData.fromJson(Map<String, dynamic> json) {
    return MonthlyData(
      month: json['month'] ?? 1,
      income: (json['income'] as num?)?.toDouble() ?? 0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CategorySummary {
  final String category;
  final double total;
  final double percent;
  CategorySummary({required this.category, required this.total, required this.percent});

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      category: json['category'] ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

final yearlyStatsProvider = FutureProvider.family<YearlyStats, int>((ref, year) async {
  final api = ref.watch(apiProvider);
  final res = await api.getYearlyStats(year: year);
  return YearlyStats.fromJson(Map<String,dynamic>.from(res));
});
