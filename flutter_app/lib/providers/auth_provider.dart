import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_service.dart';

// ==================== 敏感存储（Token用加密存储）====================
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ==================== 认证状态 ====================

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? phone;
  final String? token;
  final String? error;

  AuthState({this.isLoggedIn = false, this.isLoading = false, this.phone, this.token, this.error});

  AuthState copyWith({bool? isLoggedIn, bool? isLoading, String? phone, String? token, String? error}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      phone: phone ?? this.phone,
      token: token ?? this.token,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _loadSavedAuth();
  }

  // 启动时加载加密存储的认证信息
  Future<void> _loadSavedAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final phone = await _secureStorage.read(key: 'auth_phone');
      final token = await _secureStorage.read(key: 'auth_token');
      if (phone != null && token != null) {
        // 启动时用 token 做后端校验，不信任本地存储就直接设为已登录
        try {
          final api = ApiService(phone: phone, token: token);
          await api.me(); // 调 /api/auth/me 验证 token 有效性
          state = state.copyWith(isLoggedIn: true, isLoading: false, phone: phone, token: token);
        } catch (_) {
          // token 无效或已过期，清除加密存储
          await _secureStorage.delete(key: 'auth_phone');
          await _secureStorage.delete(key: 'auth_token');
          state = state.copyWith(isLoggedIn: false, isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // 发送验证码
  Future<void> sendCode(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiService(phone: phone);
      await api.sendCode(phone);
      state = state.copyWith(isLoading: false, phone: phone);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 验证验证码（注册或登录）
  Future<void> verifyCode(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiService(phone: phone);
      final res = await api.verifyCode(phone, code);

      final token = res['token'] as String;
      // Token 用加密存储，不再明文存 SharedPreferences
      await _secureStorage.write(key: 'auth_phone', value: phone);
      await _secureStorage.write(key: 'auth_token', value: token);

      state = state.copyWith(isLoggedIn: true, isLoading: false, phone: phone, token: token, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 旧版 PIN 登录（兼容老用户，自动迁移到 token）
  Future<void> loginWithPin(String phone, String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiService(phone: phone);
      final res = await api.login(phone, pin);

      final token = res['token'] as String?;
      if (token != null) {
        await _secureStorage.write(key: 'auth_phone', value: phone);
        await _secureStorage.write(key: 'auth_token', value: token);
        state = state.copyWith(isLoggedIn: true, isLoading: false, phone: phone, token: token, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: '登录失败，未获取到会话');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 退出登录
  Future<void> logout() async {
    final savedPhone = state.phone;
    final savedToken = state.token;

    // 清除加密存储
    await _secureStorage.delete(key: 'auth_phone');
    await _secureStorage.delete(key: 'auth_token');
    state = AuthState();

    // 调服务端 logout
    if (savedPhone != null && savedToken != null) {
      try {
        final api = ApiService(phone: savedPhone, token: savedToken);
        await api.logout();
      } catch (_) {}
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

// ==================== API Provider ====================

final apiProvider = Provider<ApiService>((ref) {
  final phone = ref.watch(authProvider).phone;
  final token = ref.watch(authProvider).token;
  if (phone == null || token == null) throw Exception('未登录');
  return ApiService(phone: phone, token: token);
});

// ==================== 分类数据 ====================

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

// ==================== 账户数据 ====================

final accountsProvider = FutureProvider<List>((ref) async {
  final api = ref.watch(apiProvider);
  final res = await api.getAccounts();
  return List<Map>.from(res['accounts'] ?? []);
});

// ==================== 月度统计 ====================

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

// ==================== 账单记录 ====================

class Record {
  final String id;
  final String type;
  final double amount;
  final String category;
  final String sub_category;
  final String account;
  final String to_account;
  final String remark;
  final String tag;
  final String date;
  final String created_at;
  Record({required this.id, required this.type, required this.amount, required this.category, required this.sub_category, required this.account, required this.to_account, required this.remark, required this.tag, required this.date, required this.created_at});
  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      category: json['category'] ?? '',
      sub_category: json['sub_category'] ?? '',
      account: json['account'] ?? '',
      to_account: json['to_account'] ?? '',
      remark: json['remark'] ?? '',
      tag: json['tag'] ?? '',
      date: json['date'] ?? '',
      created_at: json['created_at'] ?? '',
    );
  }
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
    records: (res['records'] as List? ?? []).map((r) => Record.fromJson(r as Map<String, dynamic>)).toList(),
    total: res['total'] ?? 0,
  );
});

// ==================== 分类统计 ====================

final categoryStatsProvider = FutureProvider.family<List, ({int year, int month, String type})>((ref, params) async {
  final api = ref.watch(apiProvider);
  final res = await api.getCategoryStats(year: params.year, month: params.month, type: params.type);
  return List<Map>.from(res['categories'] ?? []);
});
