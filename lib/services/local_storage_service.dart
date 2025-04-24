import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/memory.dart';
import '../models/chat_message.dart';
import 'dart:io';

class LocalStorageService {
  static const String _memoriesBoxName = 'memories';
  static const String _chatHistoryBoxName = 'chat_history';
  static String? _appDirPath;

  static Future<String> getAppDirPath() async {
    if (_appDirPath == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _appDirPath = appDir.path;
      print('[DEBUG] 应用目录路径: $_appDirPath');
    }
    return _appDirPath!;
  }

  static String getRelativeImagePath(String memoryId) {
    return 'memory_images/$memoryId.webp';
  }

  static Future<String> getAbsoluteImagePath(String relativeImagePath) async {
    final appDir = await getAppDirPath();
    return '$appDir/$relativeImagePath';
  }

  static Future<String> getMemoryImagePath(String memoryId) async {
    final relativePath = getRelativeImagePath(memoryId);
    return await getAbsoluteImagePath(relativePath);
  }

  static Future<String> ensureMemoryImagesDir() async {
    try {
      final appDir = await getAppDirPath();
      final imagesDir = Directory('$appDir/memory_images');
      
      print('[DEBUG] 检查图片目录: ${imagesDir.path}');
      final exists = await imagesDir.exists();
      print('[DEBUG] 图片目录是否存在: $exists');
      
      if (!exists) {
        print('[DEBUG] 开始创建图片目录');
        await imagesDir.create(recursive: true);
        print('[DEBUG] 图片目录创建成功: ${imagesDir.path}');
        
        // 验证目录是否真的创建成功
        final createdExists = await imagesDir.exists();
        print('[DEBUG] 验证图片目录创建: ${createdExists ? '成功' : '失败'}');
        
        if (!createdExists) {
          throw Exception('图片目录创建失败');
        }
      }
      
      // 测试目录是否可写
      try {
        final testFile = File('${imagesDir.path}/test.txt');
        await testFile.writeAsString('test');
        await testFile.delete();
        print('[DEBUG] 图片目录可写性测试通过');
      } catch (e) {
        print('[DEBUG] ⚠️ 图片目录可写性测试失败: $e');
        throw Exception('图片目录不可写');
      }
      
      return imagesDir.path;
    } catch (e) {
      print('[DEBUG] ❌ 确保图片目录存在时出错: $e');
      rethrow;
    }
  }

  static Future<void> init() async {
    print('[DEBUG] 开始初始化本地存储服务');
    
    // 注册适配器
    Hive.registerAdapter(MemoryAdapter());
    Hive.registerAdapter(ChatMessageAdapter());
    
    // 获取应用文档目录
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      print('[DEBUG] Hive 存储位置: ${appDir.path}');
    }
    
    // 打开或获取已存在的 boxes
    if (!Hive.isBoxOpen(_memoriesBoxName)) {
      print('[DEBUG] 打开记忆存储盒');
      await Hive.openBox<Memory>(_memoriesBoxName);
    }
    
    if (!Hive.isBoxOpen(_chatHistoryBoxName)) {
      print('[DEBUG] 打开聊天记录存储盒');
      await Hive.openBox<List<dynamic>>(_chatHistoryBoxName);
    }
    
    // 打印现有数据
    final memoriesBox = Hive.box<Memory>(_memoriesBoxName);
    print('[DEBUG] 本地存储中现有记忆数量: ${memoriesBox.length}');
    
    // 打印每条记忆的详细信息
    for (var i = 0; i < memoriesBox.length; i++) {
      final key = memoriesBox.keyAt(i);
      final memory = memoriesBox.get(key);
      print('[DEBUG] 记忆 $i: ID=${memory?.id}, 名称=${memory?.name}, 头像=${memory?.avatar}');
    }
  }

  static Future<void> saveMemory(Memory memory) async {
    final box = Hive.box<Memory>(_memoriesBoxName);
    await box.put(memory.id, memory);
  }

  static Future<void> saveMemories(List<Memory> memories) async {
    final box = Hive.box<Memory>(_memoriesBoxName);
    print('[DEBUG] 开始保存 ${memories.length} 条记忆到本地存储');
    await box.clear();
    for (final memory in memories) {
      print('[DEBUG] 保存记忆: ${memory.id}, ${memory.name}');
      await box.put(memory.id, memory);
    }
    print('[DEBUG] 记忆保存完成');
  }

  static List<Memory>? getMemories() {
    final box = Hive.box<Memory>(_memoriesBoxName);
    final memories = box.values.toList();
    print('[DEBUG] 从本地存储获取到 ${memories.length} 条记忆');
    for (final memory in memories) {
      print('[DEBUG] 记忆ID: ${memory.id}, 名称: ${memory.name}, 头像: ${memory.avatar}');
    }
    return memories;
  }

  static Memory? getMemory(String id) {
    final box = Hive.box<Memory>(_memoriesBoxName);
    return box.get(id);
  }

  static Future<void> deleteMemory(String id) async {
    try {
      print('[DEBUG] 开始删除记忆: $id');
      
      // 获取已打开的 boxes
      final memoriesBox = Hive.box<Memory>(_memoriesBoxName);
      final chatHistoryBox = Hive.box<List<dynamic>>(_chatHistoryBoxName);
      
      // 获取记忆对象以获取头像路径
      final memory = memoriesBox.get(id);
      if (memory != null && memory.avatar.isNotEmpty) {
        try {
          final avatarFile = File(memory.avatar);
          if (await avatarFile.exists()) {
            await avatarFile.delete();
            print('[DEBUG] 头像文件已删除: ${memory.avatar}');
          }
        } catch (e) {
          print('[DEBUG] 删除头像文件失败: $e');
        }
      }
      
      print('[DEBUG] 从本地存储中删除记忆');
      await memoriesBox.delete(id);
      print('[DEBUG] 记忆已从本地存储中删除');
      
      print('[DEBUG] 从本地存储中删除聊天记录');
      await chatHistoryBox.delete(id);
      print('[DEBUG] 聊天记录已从本地存储中删除');
      
    } catch (e) {
      print('[DEBUG] 删除记忆时出错: $e');
      rethrow;
    }
  }

  static Future<void> clearAll() async {
    final box = Hive.box<Memory>(_memoriesBoxName);
    await box.clear();
  }

  static Future<void> saveChatHistory(String memoryId, List<Map<String, dynamic>> chatHistory) async {
    print('[DEBUG] 开始保存聊天记录，记忆ID: $memoryId');
    final box = Hive.box<List<dynamic>>(_chatHistoryBoxName);
    print('[DEBUG] 保存 ${chatHistory.length} 条聊天记录');
    await box.put(memoryId, chatHistory);
    print('[DEBUG] 聊天记录保存完成');
  }

  static List<Map<String, dynamic>>? getChatHistory(String memoryId) {
    print('[DEBUG] 开始获取聊天记录，记忆ID: $memoryId');
    final box = Hive.box<List<dynamic>>(_chatHistoryBoxName);
    final history = box.get(memoryId);
    print('[DEBUG] 获取到 ${history?.length ?? 0} 条聊天记录');
    
    if (history == null) {
      print('[DEBUG] 没有找到聊天记录');
      return null;
    }
    
    // 确保返回的是正确的类型
    final convertedHistory = history.map((item) => Map<String, dynamic>.from(item)).toList();
    print('[DEBUG] 转换后的聊天记录数量: ${convertedHistory.length}');
    return convertedHistory;
  }

  static Future<void> printDirectoryStructure() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      print('\n[DEBUG] ======= 目录结构 =======');
      print('[DEBUG] 应用文档根目录: ${appDir.path}');
      
      // 列出根目录下的所有内容
      final rootContents = await appDir.list().toList();
      print('[DEBUG] 根目录内容:');
      for (var entity in rootContents) {
        print('[DEBUG] - ${entity.path}');
        
        // 如果是目录，列出其内容
        if (entity is Directory) {
          final subContents = await entity.list().toList();
          for (var subEntity in subContents) {
            print('[DEBUG]   └─ ${subEntity.path}');
          }
        }
      }
      
      // 特别检查 memory_images 目录
      final imagesDir = Directory('${appDir.path}/memory_images');
      if (await imagesDir.exists()) {
        print('\n[DEBUG] memory_images 目录内容:');
        final imageFiles = await imagesDir.list().toList();
        for (var file in imageFiles) {
          if (file is File) {
            final size = await file.length();
            print('[DEBUG] - ${file.path} (${size} bytes)');
          }
        }
      } else {
        print('\n[DEBUG] ⚠️ memory_images 目录不存在！');
      }
      
      print('[DEBUG] =======================\n');
    } catch (e) {
      print('[DEBUG] 打印目录结构时出错: $e');
    }
  }

  static Future<String> getUserAvatarPath() async {
    try {
      final appDir = await getAppDirPath();
      final avatarPath = '$appDir/user_avatar.webp';
      final file = File(avatarPath);
      if (await file.exists()) {
        return avatarPath;
      }
      return '';
    } catch (e) {
      print('[DEBUG] 获取用户头像路径失败: $e');
      return '';
    }
  }
} 