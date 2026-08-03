import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// 默认后端地址（可在App设置里改）
// NAS内网： http://192.168.31.150:3848
// bore.pub： http://bore.pub:38864（临时，端口会变）
// Tailscale IP： http://<tailscale_ip>:3848（永久方案）
const String DEFAULT_BASE_URL = 'http://192.168.31.150:3848';

// 动态获取 BASE_URL（优先读 SharedPreferences，兜底用默认值）
Future<String> getBaseUrl() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('base_url') ?? DEFAULT_BASE_URL;
  } catch (_) {
    return DEFAULT_BASE_URL;
  }
}

// 同步获取（首次读取用默认值，后续由 setBaseUrl 刷新）
String _currentBaseUrl = DEFAULT_BASE_URL;

void setBaseUrl(String url) {
  _currentBaseUrl = url;
}

String get baseUrl => _currentBaseUrl;

class ApiService {
  final String phone;
  final String? token;  // v2.0.0 新增
  // baseUrl 现在是全局动态的，不再用实例字段

  ApiService({required this.phone, this.token});

  // v2.0.0: 优先用 x-token，兼容旧 x-phone
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'x-token': token!,
        'x-phone': phone,
      };

  // ==================== 认证（v2.0.0 短信验证码）====================

  /// 发送短信验证码（60秒有效）
  Future<Map> sendCode(String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/send_code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    return _handle(res);
  }

  /// 验证验证码（注册+登录合一，返回 token）
  /// [phone] 手机号
  /// [code] 6位验证码
  Future<Map> verifyCode(String phone, String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/verify_code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    return _handle(res);
  }

  /// 验证 Token 有效性（启动时自动登录校验）
  Future<Map> me() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _headers,
    );
    return _handle(res);
  }

  /// 退出登录
  Future<Map> logout() async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/auth/logout'),
      headers: _headers,
    );
    return _handle(res);
  }

  // ==================== 旧版认证（兼容 v1.x，v2.1 废弃）====================

  /// 旧版 PIN 注册（废弃）
  Future<Map> register(String phone, String pin) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'pin': pin}),
    );
    return _handle(res);
  }

  /// 旧版 PIN 登录（兼容老用户，自动迁移到 token）
  Future<Map> login(String phone, String pin) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'pin': pin}),
    );
    return _handle(res);
  }

  // ==================== 账单 ====================

  Future<Map> getRecords({
    int page = 1,
    int limit = 50,
    String? startDate,
    String? endDate,
    String? type,
    String? category,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;
    if (type != null) params['type'] = type;
    if (category != null) params['category'] = category;

    final uri = Uri.parse('$baseUrl/api/records').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  Future<Map> addRecord(Map record) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/records'),
      headers: _headers,
      body: jsonEncode(record),
    );
    return _handle(res);
  }

  Future<Map> updateRecord(String id, Map record) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/records/$id'),
      headers: _headers,
      body: jsonEncode(record),
    );
    return _handle(res);
  }

  Future<Map> deleteRecord(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/records/$id'),
      headers: _headers,
    );
    return _handle(res);
  }

  // ==================== 统计 ====================

  Future<Map> getMonthlyStats({int? year, int? month}) async {
    final params = <String, String>{};
    if (year != null) params['year'] = year.toString();
    if (month != null) params['month'] = month.toString();

    final uri = Uri.parse('$baseUrl/api/stats/monthly').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  Future<Map> getCategoryStats({int? year, int? month, String type = 'expense'}) async {
    final params = <String, String>{'type': type};
    if (year != null) params['year'] = year.toString();
    if (month != null) params['month'] = month.toString();

    final uri = Uri.parse('$baseUrl/api/stats/category').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  // ==================== 分类 ====================

  Future<Map> getCategories({String? type}) async {
    final uri = Uri.parse('$baseUrl/api/categories').replace(
      queryParameters: type != null ? {'type': type} : null,
    );
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  Future<Map> addCategory(Map cat) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/categories'),
      headers: _headers,
      body: jsonEncode(cat),
    );
    return _handle(res);
  }

  Future<Map> deleteCategory(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/categories/$id'),
      headers: _headers,
    );
    return _handle(res);
  }

  // ==================== 账户 ====================

  Future<Map> getAccounts() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/accounts'),
      headers: _headers,
    );
    return _handle(res);
  }

  Future<Map> addAccount(String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/accounts'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return _handle(res);
  }

  Future<Map> deleteAccount(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/accounts/$id'),
      headers: _headers,
    );
    return _handle(res);
  }

  // ==================== 导出 ====================

  Future<String> exportCsv({String? startDate, String? endDate}) async {
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;

    final uri = Uri.parse('$baseUrl/api/export/csv').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return utf8.decode(res.bodyBytes);
    }
    throw Exception('导出失败: ${res.statusCode}');
  }

  // 导入钱迹CSV
  Future<Map> importQianjiCsv(String csvContent) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/import/qianji'),
      headers: _headers,
      body: jsonEncode({'csv': csvContent}),
    );
    return _handle(res);
  }

  Map _handle(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw ApiException(body['error'] ?? '请求失败', res.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
