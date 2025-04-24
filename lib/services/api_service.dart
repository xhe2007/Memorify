import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';
import '../config/api_config.dart';

class ApiService {

  static const String baseUrl = '${ApiConfig.baseUrl}';

  static Future<String> _getUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString('user_uuid');
    if (uuid == null) {
      uuid = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('user_uuid', uuid);
    }
    return uuid;
  }

  static Future<List<Memory>> getMemories(String uuid) async {
    print('[DEBUG] 开始从服务器获取记忆，UUID: $uuid');
    final response = await http.get(Uri.parse('$baseUrl/memories?uuid=$uuid'));
    print('[DEBUG] 服务器响应状态码: ${response.statusCode}');
    print('[DEBUG] 服务器响应内容: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      print('[DEBUG] 解析到 ${jsonData.length} 条记忆数据');
      return jsonData.map((json) => Memory.fromJson(json)).toList();
    } else {
      print('[DEBUG] 获取记忆失败，状态码: ${response.statusCode}');
      throw Exception('Failed to load memories');
    }
  }

  static Future<http.MultipartRequest> createMemoryUploadRequest({
    required String name,
    required String gender,
    required String ageGroup,
    required String personality,
    required String filePath,
  }) async {
    final uuid = await _getUUID();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload?uuid=$uuid'))
      ..fields['name'] = name
      ..fields['gender'] = gender
      ..fields['ageGroup'] = ageGroup
      ..fields['personality'] = personality
      ..files.add(await http.MultipartFile.fromPath('photo', filePath));

    return request;
  }

  static Future<Response> sendChatMessage(String memoryId, String message) async {
    final uuid = await _getUUID();
    return await http.post(
      Uri.parse('$baseUrl/chat?uuid=$uuid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({ 'memoryId': memoryId, 'message': message }),
    );
  }
}

class UserService {
  static const String baseUrl = '${ApiConfig.baseUrl}';

  static Future<String> _getUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString('user_uuid');
    if (uuid == null) {
      uuid = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('user_uuid', uuid);
    }
    return uuid;
  }

  static Future<String?> getUserAvatar() async {
    final uuid = await _getUUID();
    final res = await http.get(Uri.parse('$baseUrl/user?uuid=$uuid'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['avatar']?.toString();
    }
    return null;
  }

  static Future<http.MultipartRequest> createUserProfileUpdateRequest({
    String? name,
    String? photoPath,
  }) async {
    final uuid = await _getUUID();
    final request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/user?uuid=$uuid'));
    if (name != null) request.fields['name'] = name;
    if (photoPath != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    }
    return request;
  }
}