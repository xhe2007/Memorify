import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UUIDHelper {
  static const _key = 'user_uuid';

  static Future<String> getOrCreateUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString(_key);
    if (uuid == null) {
      uuid = Uuid().v4();
      await prefs.setString(_key, uuid);
      print('[UUID] 新生成 UUID: $uuid');
    } else {
      print('[UUID] 已存在 UUID: $uuid');
    }
    return uuid;
  }
}