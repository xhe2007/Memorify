import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/locale_provider.dart';
import 'memory_list_page.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/custom_page_route.dart';

class IntroPage extends StatefulWidget {
  @override
  _IntroPageState createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with SingleTickerProviderStateMixin {
  int _step = 0; // 0: welcome, 1: language, 2: profile
  File? _image;
  final TextEditingController _nameController = TextEditingController();
  bool _isUploading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _step++;
    });
    _animationController.forward(from: 0.0);
  }

  void _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<String> _getUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_uuid') ?? '';
  }

  Future<void> _submit() async {
    setState(() => _isUploading = true);
    try {
      final uuid = await _getUuid();
      final request = http.MultipartRequest('PUT', Uri.parse('${ApiConfig.baseUrl}/user?uuid=$uuid'));
      if (_nameController.text.isNotEmpty) {
        request.fields['name'] = _nameController.text;
      }
      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', _image!.path));
      }
      final response = await request.send();
      setState(() => _isUploading = false);

      if (response.statusCode == 200) {
        _completeIntro();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传失败'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络错误'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenIntro', true);
    _navigateToMemoryList();
  }

  void _navigateToMemoryList() {
    Navigator.of(context).pushReplacement(
      SlidePageRoute(
        page: MemoryListPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final locale = localeProvider.locale;
    final theme = Theme.of(context);

    final localized = {
      '中文': {
        'welcome': '欢迎使用 Memorify',
        'continue': '继续',
        'selectLanguage': '请选择语言',
        'next': '下一步',
        'uploadPhoto': '上传头像',
        'enterName': '请输入你的名字',
        'skip': '跳过',
        'start': '开始',
      },
      'English': {
        'welcome': 'Welcome to Memorify',
        'continue': 'Continue',
        'selectLanguage': 'Please select your language',
        'next': 'Next',
        'uploadPhoto': 'Upload Your Avatar',
        'enterName': 'Enter your name',
        'skip': 'Skip',
        'start': 'Start',
      },
    }[locale]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 800),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        child: SafeArea(
          key: ValueKey<int>(_step),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor.withOpacity(0.9),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: _step == 0
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/welcome.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.memory,
                                        size: 80,
                                        color: theme.primaryColor,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        localized['welcome']!,
                                        style: theme.textTheme.headlineMedium?.copyWith(
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _nextStep,
                                style: ElevatedButton.styleFrom(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      localized['continue']!,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _step == 1
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                localized['selectLanguage']!,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: theme.primaryColor,
                                ),
                              ),
                              SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButton<String>(
                                  value: locale,
                                  items: ['中文', 'English']
                                      .map((lang) => DropdownMenuItem(
                                            value: lang,
                                            child: Text(
                                              lang,
                                              style: theme.textTheme.bodyLarge,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) => localeProvider.setLocale(value!),
                                  isExpanded: true,
                                  underline: SizedBox(),
                                  icon: Icon(Icons.language, color: theme.primaryColor),
                                ),
                              ),
                              SizedBox(height: 32),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _nextStep,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          localized['next']!,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                localized['uploadPhoto']!,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: theme.primaryColor,
                                ),
                              ),
                              SizedBox(height: 24),
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
                              SizedBox(height: 24),
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: localized['enterName'],
                                  prefixIcon: Icon(Icons.person, color: theme.primaryColor),
                                ),
                                style: theme.textTheme.bodyLarge,
                              ),
                              SizedBox(height: 32),
                              if (_isUploading)
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: SizedBox(
                                          height: 56,
                                          child: TextButton(
                                            onPressed: _completeIntro,
                                            style: TextButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: Text(
                                              localized['skip']!,
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                color: theme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: SizedBox(
                                          height: 56,
                                          child: ElevatedButton(
                                            onPressed: _submit,
                                            style: ElevatedButton.styleFrom(
                                              elevation: 4,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  localized['start']!,
                                                  style: theme.textTheme.bodyLarge?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(Icons.check),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}