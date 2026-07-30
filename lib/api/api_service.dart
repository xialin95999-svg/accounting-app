import 'dart:convert';
import 'package:http/http.dart' as http;

// ECS 云服务器后端地址
const String BASE_URL = 'http://116.62.117.199:3848';

class ApiService {
  final String phone;
  final String baseUrl;

  ApiService({required this.phone, String? baseUrl})
      : baseUrl = baseUrl ?? BASE_URL;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-phone': phone,
      };

  // ==================== 认证 ====================

  Future<Map> register(String phone, String pin) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'pin': pin}),
    );
    return _handle(res);
  }

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
