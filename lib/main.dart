import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'pages/intro_page.dart';
import 'pages/memory_list_page.dart';
import 'providers/locale_provider.dart';
import 'theme/app_theme.dart';
import 'services/local_storage_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive 和本地存储
  print('[DEBUG] 开始初始化 Hive');
  await Hive.initFlutter();
  print('[DEBUG] Hive 初始化完成');
  
  print('[DEBUG] 开始初始化本地存储服务');
  await LocalStorageService.init();
  print('[DEBUG] 本地存储服务初始化完成');

  // 获取用户 UUID
  final prefs = await SharedPreferences.getInstance();
  final seenIntro = prefs.getBool('seenIntro') ?? false;
 
  if (!prefs.containsKey('user_uuid')) {
    final uuid = Uuid().v4();
    await prefs.setString('user_uuid', uuid);
    print('[DEBUG] 创建新用户 UUID: $uuid');
  } else {
    final uuid = prefs.getString('user_uuid');
    print('[DEBUG] 使用现有用户 UUID: $uuid');
  }

  final localeProvider = LocaleProvider();
  await localeProvider.loadLocale();

  runApp(
    ChangeNotifierProvider.value(
      value: localeProvider,
      child: MyApp(showIntro: !seenIntro),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showIntro;

  const MyApp({super.key, required this.showIntro});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memorify',
      theme: AppTheme.lightTheme,
      home: showIntro ? IntroPage() : MemoryListPage(),
      navigatorObservers: [routeObserver],
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: child,
        );
      },
    );
  }
}