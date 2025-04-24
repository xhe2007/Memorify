import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../config/api_config.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/custom_page_route.dart';

class UserProfilePage extends StatefulWidget {
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final TextEditingController nameController = TextEditingController();
  File? _image;
  String? _base64Image;
  String _language = '中文';

  final Map<String, Map<String, String>> _localizedText = {
    '中文': {
      'title': '个人资料',
      'name': '你的名字',
      'language': '语言',
      'save': '保存资料',
      'success': '资料更新成功',
      'fail': '更新失败',
    },
    'English': {
      'title': 'Profile',
      'name': 'Your Name',
      'language': 'Language',
      'save': 'Save Profile',
      'success': 'Profile updated successfully',
      'fail': 'Update failed',
    }
  };

  Map<String, String> get _text => _localizedText[_language]!;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // 首先尝试从本地加载头像
      final appDir = await getApplicationDocumentsDirectory();
      final avatarPath = '${appDir.path}/user_avatar.webp';
      final avatarFile = File(avatarPath);
      
      if (await avatarFile.exists()) {
        setState(() {
          _image = avatarFile;
          _base64Image = null;
        });
        print('[DEBUG] 从本地加载用户头像: $avatarPath');
      }
      
      // 然后从服务器加载其他信息
      final uuid = await _getUuid();
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/user?uuid=$uuid'));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        setState(() {
          nameController.text = data['name'] ?? '';
        });
      }
    } catch (e) {
      print('[❌] 获取用户资料失败: $e');
    }
  }

  Future<String> _getUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_uuid') ?? '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _base64Image = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!mounted) return;
    
    try {
    final uuid = await _getUuid();
    final uri = Uri.parse('${ApiConfig.baseUrl}/user?uuid=$uuid');
    final request = http.MultipartRequest('PUT', uri);
    request.fields['name'] = nameController.text;

    if (_image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final avatarPath = '${appDir.path}/user_avatar.webp';
        await _image!.copy(avatarPath);
        print('[DEBUG] 用户头像已保存到本地: $avatarPath');
        
      request.files.add(await http.MultipartFile.fromPath('photo', _image!.path));
    }

    final response = await request.send();

      if (!mounted) return;

    if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text['success']!))
        );
    } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text['fail']!))
        );
      }
    } catch (e) {
      print('[❌] 更新用户资料失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text['fail']!))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    _language = localeProvider.locale;

    ImageProvider? avatarProvider;
    if (_image != null) {
      avatarProvider = FileImage(_image!);
    } else if (_base64Image != null) {
      final bytes = base64Decode(_base64Image!.split(',').last);
      avatarProvider = MemoryImage(bytes);
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
      appBar: AppBar(title: Text(_text['title']!)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: avatarProvider,
                child: avatarProvider == null ? Icon(Icons.add_a_photo, size: 40) : null,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: _text['name']),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _language,
              items: ['中文', 'English']
                  .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  localeProvider.setLocale(val);
                }
              },
              decoration: InputDecoration(labelText: _text['language']),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: Text(_text['save']!),
            ),
          ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }
}