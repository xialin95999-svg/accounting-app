import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_service.dart';

// 认证状态
class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? phone;
  final String? error;

  AuthState({this.isLoggedIn = false, this.isLoading = false, this.phone, this.error});

  AuthState copyWith({bool? isLoggedIn, bool? isLoading, String? phone, String? error}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      phone: phone ?? this.phone,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    if (phone != null) {
      state = state.copyWith(isLoggedIn: true, phone: phone);
    }
  }

  Future<void> register(String phone, String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiService(phone: phone);
      await api.register(phone, pin);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone', phone);
      state = state.copyWith(isLoggedIn: true, isLoading: false, phone: phone);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> login(String phone, String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiService(phone: phone);
      await api.login(phone, pin);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone', phone);
      state = state.copyWith(isLoggedIn: true, isLoading: false, phone: phone);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone');
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

// API Provider
final apiProvider = Provider<ApiService>((ref) {
  final phone = ref.watch(authProvider).phone;
  if (phone == null) throw Exception('未登录');
  return ApiService(phone: phone);
});

// 分类数据
class CategoryData {
  final List<Map> expenseCategories;
  final List<Map> incomeCategories;

  CategoryData({this.expenseCategories = const [], this.incomeCategories = const []});
}

final categoriesProvider = FutureProvider<CategoryData>((ref) async {
  final api = ref.watch(apiProvider);
  final expenseRes = await api.getCategories(type: 'expense');
  final incomeRes = await api.getCategories(type: 'income');
  return CategoryData(
    expenseCategories: List<Map>.from(expenseRes['categories'] ?? []),
    incomeCategories: List<Map>.from(incomeRes['categories'] ?? []),
  );
});

// 账户数据
final accountsProvider = FutureProvider<List>((ref) async {
  final api = ref.watch(apiProvider);
  final res = await api.getAccounts();
  return List<Map>.from(res['accounts'] ?? []);
});

// 月度统计
class MonthlyStats {
  final int year;
  final int month;
  final double income;
  final double expense;
  final double balance;
  final List<Map> daily;

  MonthlyStats({required this.year, required this.month, required this.income, required this.expense, required this.balance, required this.daily});
}

final monthlyStatsProvider = FutureProvider.family<MonthlyStats, ({int year, int month})>((ref, params) async {
  final api = ref.watch(apiProvider);
  final res = await api.getMonthlyStats(year: params.year, month: params.month);
  return MonthlyStats(
    year: res['year'],
    month: res['month'],
    income: (res['income'] as num).toDouble(),
    expense: (res['expense'] as num).toDouble(),
    balance: (res['balance'] as num).toDouble(),
    daily: List<Map>.from(res['daily'] ?? []),
  );
});

// 账单列表
class RecordsData {
  final List<Map> records;
  final int total;

  RecordsData({required this.records, required this.total});
}

final recordsProvider = FutureProvider.family<RecordsData, Map<String, dynamic>>((ref, params) async {
  final api = ref.watch(apiProvider);
  final res = await api.getRecords(
    page: params['page'] ?? 1,
    limit: params['limit'] ?? 50,
    startDate: params['startDate'],
    endDate: params['endDate'],
    type: params['type'],
    category: params['category'],
  );
  return RecordsData(
    records: List<Map>.from(res['records'] ?? []),
    total: res['total'] ?? 0,
  );
});

// 分类统计
final categoryStatsProvider = FutureProvider.family<List, ({int year, int month, String type})>((ref, params) async {
  final api = ref.watch(apiProvider);
  final res = await api.getCategoryStats(year: params.year, month: params.month, type: params.type);
  return List<Map>.from(res['categories'] ?? []);
});
