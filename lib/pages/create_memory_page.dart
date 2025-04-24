import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';
import 'chat_page.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../utils/uuid_helper.dart';
import '../config/api_config.dart';
import '../services/local_storage_service.dart';
import 'package:path_provider/path_provider.dart';

class CreateMemoryPage extends StatefulWidget {
  @override
  _CreateMemoryPageState createState() => _CreateMemoryPageState();
}

class _CreateMemoryPageState extends State<CreateMemoryPage> with SingleTickerProviderStateMixin {
  File? _image;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _personalityController = TextEditingController();
  String gender = '男生';
  String ageGroup = '更年长';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String? uuid;
  ImageSource? _selectedImage;
  String? _selectedGender;
  String? _selectedAgeGroup;

  final Map<String, Map<String, String>> _localizedText = {
    '中文': {
      'title': '创建你的Memory',
      'name': '给这个记忆起个名字吧',
      'gender': '这个人是？',
      'age': '我希望这段记忆看起来',
      'personality': '你们曾经共有的一段记忆',
      'submit': '上传',
      'processing': '预测处理中',
      'waiting': '这通常会花费一些时间',
      'success': '创建成功',
      'startChat': '已成功生成照片，点击按钮开始聊天。',
      'chat': '开始聊天',
      'fail': '上传失败',
      'network': '预测过程发生了未知错误，但或许你仍然可以和这个记忆对话？',
      'incomplete': '请填写完整信息并上传头像',
      'ok': '好的',
    },
    'English': {
      'title': 'Create Your Memory',
      'name': 'Name your Memory',
      'gender': 'Gender',
      'age': 'This memory should look',
      'personality': 'A shared moment or trait',
      'submit': 'Upload',
      'processing': 'Predicting Photo',
      'waiting': 'It usually takes some time',
      'success': 'Created Successfully',
      'startChat': 'Photo is ready, start chatting!',
      'chat': 'Start Chatting',
      'fail': 'Upload failed',
      'network': 'An unknown error occurred, but maybe you can still chat with this memory?',
      'incomplete': 'Please complete all fields and upload a photo',
      'ok': 'OK',
    }
  };

  Map<String, String> get _text {
    final locale = context.read<LocaleProvider>().locale;
    return _localizedText[locale]!;
  }

  @override
  void initState() {
    super.initState();
    _loadUuid();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUuid() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      uuid = prefs.getString('uuid');
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  void _showMessage(String text) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
        ),
        backgroundColor: theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _createMemory() async {
    if (_image == null) {
      _showMessage(_text['incomplete']!);
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showMessage('请输入名字');
      return;
    }

    if (_personalityController.text.trim().isEmpty) {
      _showMessage('请输入一段共同的记忆');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uuid = await UUIDHelper.getOrCreateUUID();
      final memoryId = 'memory_${DateTime.now().millisecondsSinceEpoch}';
      
      print('[DEBUG] 开始上传照片，参数：');
      print('name: ${_nameController.text}');
      print('gender: $gender');
      print('ageGroup: $ageGroup');
      print('personality: ${_personalityController.text}');
      
      // 首先上传照片到服务器进行处理
      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/upload'))
        ..fields['name'] = _nameController.text.trim()
        ..fields['gender'] = (gender == '男生' || gender == 'Male') ? 'boy' : 'girl'
        ..fields['ageGroup'] = (ageGroup == '更年长' || ageGroup == 'Older') ? 'child' : 'elder'
        ..fields['personality'] = _personalityController.text.trim()
        ..files.add(await http.MultipartFile.fromPath('photo', _image!.path));

      print('[DEBUG] 开始上传照片到服务器');
      final response = await request.send();
      final body = await response.stream.bytesToString();
      print('[DEBUG] 服务器响应: $body');

      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        final imageData = data['imageData'] as String;
        print('[DEBUG] 服务器处理完成，获得图片数据');

        // 确保图片目录存在
        await LocalStorageService.ensureMemoryImagesDir();
        
        // 获取图片保存路径
        final relativePath = LocalStorageService.getRelativeImagePath(memoryId);
        final absolutePath = await LocalStorageService.getAbsoluteImagePath(relativePath);
        print('[DEBUG] 图片相对路径: $relativePath');
        print('[DEBUG] 图片绝对路径: $absolutePath');
        
        // 保存图片到本地
        final imageBytes = base64Decode(imageData.split(',').last);
        await File(absolutePath).writeAsBytes(imageBytes);
        print('[DEBUG] 图片已保存到本地: $absolutePath');

        // 创建新的记忆对象
        final memory = Memory(
          id: memoryId,
          name: _nameController.text.trim(),
          gender: (gender == '男生' || gender == 'Male') ? 'boy' : 'girl',
          ageGroup: (ageGroup == '更年长' || ageGroup == 'Older') ? 'child' : 'elder',
          personality: _personalityController.text.trim(),
          avatar: relativePath,
          creationDate: DateTime.now().toIso8601String(),
          chatHistory: [],
          uuid: uuid,
        );

        // 保存到本地存储
        await LocalStorageService.saveMemory(memory);
        print('[DEBUG] 新记忆已保存到本地存储');
        
        // 验证图片文件是否存在
        final savedFile = File(absolutePath);
        if (await savedFile.exists()) {
          print('[DEBUG] 确认图片文件已保存: ${await savedFile.length()} 字节');
          // 打印完整目录结构
          await LocalStorageService.printDirectoryStructure();
        } else {
          print('[DEBUG] 警告：图片文件不存在: $absolutePath');
          // 打印完整目录结构以便调试
          await LocalStorageService.printDirectoryStructure();
        }

        if (mounted) {
          // 显示成功对话框
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(
              _text['success']!,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(absolutePath),
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                SizedBox(height: 16),
                Text(
                  _text['startChat']!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: Icon(Icons.check),
                label: Text(_text['chat']!),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => ChatPage(memory: memory, fromCreate: true)),
                  );
                },
              )
            ],
          ),
        );
        }
      } else {
        print('[DEBUG] 服务器处理失败: ${response.statusCode}, body: $body');
        throw Exception('服务器处理失败');
      }
    } catch (e) {
      print('[DEBUG] 创建记忆失败: $e');
      if (mounted) {
        _showMessage(_text['fail']!);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final genderItems = locale == 'English' ? ['Male', 'Female'] : ['男生', '女生'];
    final ageItems = locale == 'English' ? ['Older', 'Younger'] : ['更年长', '更年轻'];
    final theme = Theme.of(context);

    if (!genderItems.contains(gender)) gender = genderItems.first;
    if (!ageItems.contains(ageGroup)) ageGroup = ageItems.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _text['title']!,
          style: theme.textTheme.headlineMedium?.copyWith(color: theme.primaryColor),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Stack(
        children: [
          FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
              child: Form(
                key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _image != null
                        ? ClipOval(
                            child: Image.file(
                              _image!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: theme.primaryColor,
                          ),
                  ),
                ),
                SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _text['name'],
                    prefixIcon: Icon(Icons.person, color: theme.primaryColor),
                  ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入名字';
                          }
                          return null;
                        },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: gender,
                        items: genderItems.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => gender = newValue);
                          }
                        },
                  decoration: InputDecoration(
                    labelText: _text['gender'],
                          prefixIcon: Icon(Icons.wc, color: theme.primaryColor),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: ageGroup,
                        items: ageItems.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => ageGroup = newValue);
                          }
                        },
                  decoration: InputDecoration(
                    labelText: _text['age'],
                          prefixIcon: Icon(Icons.access_time, color: theme.primaryColor),
                  ),
                ),
                SizedBox(height: 16),
                      TextFormField(
                        controller: _personalityController,
                  decoration: InputDecoration(
                    labelText: _text['personality'],
                    prefixIcon: Icon(Icons.psychology, color: theme.primaryColor),
                  ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入一段共同的记忆';
                          }
                          return null;
                        },
                        maxLines: 3,
                ),
                SizedBox(height: 32),
                      SizedBox(
                  width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(Icons.cloud_upload),
                          label: Text(_isLoading ? _text['processing']! : _text['submit']!),
                    style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                          onPressed: _isLoading ? null : _createMemory,
                          ),
                        ),
                      ],
                    ),
                  ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      _text['waiting']!,
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}