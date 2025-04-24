import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import '../services/local_storage_service.dart';

part 'memory.g.dart';

@HiveType(typeId: 0)
class Memory extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String gender;
  
  @HiveField(3)
  final String ageGroup;
  
  @HiveField(4)
  final String personality;
  
  @HiveField(5)
  final String avatar; // 现在存储相对路径
  
  @HiveField(6)
  final String creationDate;
  
  @HiveField(7)
  final List<Map<String, dynamic>> chatHistory;
  
  @HiveField(8)
  final String uuid; // ✅ 新增字段：每条 Memory 属于哪个用户

  Memory({
    required this.id,
    required this.name,
    required this.gender,
    required this.ageGroup,
    required this.personality,
    required this.avatar,
    required this.creationDate,
    required this.chatHistory,
    required this.uuid, // ✅ 新增
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    print('[DEBUG] 开始解析记忆数据: $json');
    final memory = Memory(
      id: json['id'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String,
      ageGroup: json['ageGroup'] as String,
      personality: json['personality'] as String,
      avatar: json['avatar'] ?? '',
      creationDate: json['creationDate'] ?? '',
      chatHistory: (json['chatHistory'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      uuid: json['uuid'] ?? '',
    );
    print('[DEBUG] 解析完成: ${memory.name}, 头像: ${memory.avatar}');
    return memory;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'ageGroup': ageGroup,
      'personality': personality,
      'avatar': avatar,
      'creationDate': creationDate,
      'chatHistory': chatHistory,
      'uuid': uuid, // ✅ 加入 uuid 到序列化
    };
  }

  // 获取头像的绝对路径
  Future<String> getAvatarAbsolutePath() async {
    if (avatar.isEmpty) return '';
    return await LocalStorageService.getAbsoluteImagePath(avatar);
  }

  Widget buildListTile() {
    return ListTile(
      leading: ClipOval(
        child: avatar.isNotEmpty
          ? FutureBuilder<String>(
              future: getAvatarAbsolutePath(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return Image.file(
                    File(snapshot.data!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
                      print('[DEBUG] 加载头像失败: $error');
                      return Icon(Icons.person, color: Colors.grey);
                    },
                  );
                }
                return Icon(Icons.person, color: Colors.grey);
          },
            )
          : Icon(Icons.person, color: Colors.grey),
      ),
      title: Text(name),
    );
  }
}