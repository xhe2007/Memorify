import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';
import '../providers/locale_provider.dart';
import '../utils/uuid_helper.dart';
import '../config/api_config.dart';
import '../services/local_storage_service.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'dart:io';
import '../utils/custom_page_route.dart';

class ChatPage extends StatefulWidget {
  final Memory memory;
  final bool fromCreate;

  ChatPage({required this.memory, this.fromCreate = false});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _memoryTyping = false;
  Timer? _typingAnimationTimer;
  String _typingText = '...';
  bool _userScrolled = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final isBottom = _scrollController.position.pixels == _scrollController.position.maxScrollExtent;
      _userScrolled = !isBottom;
    });
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      print('[DEBUG] 开始加载聊天记录，记忆ID: ${widget.memory.id}');
      final localHistory = LocalStorageService.getChatHistory(widget.memory.id);
      print('[DEBUG] 本地存储中的聊天记录: ${localHistory?.length ?? 0} 条');
      
      if (localHistory != null && localHistory.isNotEmpty) {
        print('[DEBUG] 使用本地存储的聊天记录');
          setState(() {
          _messages = localHistory
              ..sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      print('[DEBUG] 加载聊天记录失败: $e');
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final timestamp = DateTime.now().toIso8601String();
    final userMessage = {'sender': 'user', 'message': text, 'timestamp': timestamp};
    
    setState(() {
      _messages.add(userMessage);
    });
    _controller.clear();
    _scrollToBottom();

    setState(() => _memoryTyping = true);
    _startTypingAnimation();

    try {
      // 发送聊天请求到服务器，包含历史记录
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'personality': widget.memory.personality,
          'name': widget.memory.name,
          'chatHistory': _messages  // 发送历史记录给服务器
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final reply = data['response']?.toString().trim() ?? '[无响应]';
        final replyTime = DateTime.now().toIso8601String();
        final memoryMessage = {'sender': 'memory', 'message': reply, 'timestamp': replyTime};

        setState(() {
          _messages.add(memoryMessage);
          _memoryTyping = false;
        });
        _typingAnimationTimer?.cancel();
        _scrollToBottom();

        // 保存更新后的聊天记录到本地
        await LocalStorageService.saveChatHistory(widget.memory.id, _messages);
        
        // 更新记忆对象中的聊天记录
        final updatedMemory = Memory(
          id: widget.memory.id,
          name: widget.memory.name,
          gender: widget.memory.gender,
          ageGroup: widget.memory.ageGroup,
          personality: widget.memory.personality,
          avatar: widget.memory.avatar,
          creationDate: widget.memory.creationDate,
          chatHistory: _messages,
          uuid: widget.memory.uuid,
        );
        
        // 更新本地存储中的记忆
        final memoriesBox = Hive.box<Memory>('memories');
        await memoriesBox.put(widget.memory.id, updatedMemory);
        print('[DEBUG] 聊天记录已更新到本地存储');
      }
    } catch (e) {
      print('[❌] 聊天发送失败: $e');
      setState(() {
      _memoryTyping = false;
        _messages.add({
          'sender': 'system',
          'message': '发送失败，请重试',
          'timestamp': DateTime.now().toIso8601String()
        });
      });
      _typingAnimationTimer?.cancel();
    }
  }

  void _startTypingAnimation() {
    int dotCount = 1;
    _typingAnimationTimer?.cancel();
    _typingAnimationTimer = Timer.periodic(Duration(milliseconds: 500), (_) {
      setState(() {
        _typingText = '${_getText('typing')}${'.' * dotCount}';
        dotCount = dotCount == 3 ? 1 : dotCount + 1;
      });
    });
  }

  void _scrollToBottom() {
    if (!_userScrolled) {
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _getText(String key) {
    final lang = context.read<LocaleProvider>().locale;
    final map = {
      '中文': {'typing': '对方正在输入中', 'hint': '想跟Ta说什么...'},
      'English': {'typing': 'Typing', 'hint': 'Say something...'}
    };
    return map[lang]?[key] ?? key;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingAnimationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildAvatar(bool isUser) {
    if (isUser) {
      return FutureBuilder<String>(
        future: LocalStorageService.getUserAvatarPath(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return CircleAvatar(
              radius: 20,
              backgroundImage: FileImage(File(snapshot.data!)),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onBackgroundImageError: (exception, stackTrace) {
                print('[DEBUG] 加载用户头像失败: $exception');
                return;
              },
            );
          }
          return CircleAvatar(
            radius: 20,
            child: Icon(Icons.person, size: 20, color: Theme.of(context).primaryColor),
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          );
        },
      );
    } else if (widget.memory.avatar.isNotEmpty) {
      return FutureBuilder<String>(
        future: widget.memory.getAvatarAbsolutePath(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return CircleAvatar(
              radius: 20,
              backgroundImage: FileImage(File(snapshot.data!)),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onBackgroundImageError: (exception, stackTrace) {
                print('[DEBUG] 加载记忆头像失败: $exception');
                return;
              },
            );
          }
          return CircleAvatar(
            radius: 20,
            child: Icon(Icons.person, size: 20, color: Theme.of(context).primaryColor),
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          );
        },
      );
    }
    return CircleAvatar(
      radius: 20,
      child: Icon(Icons.person, size: 20, color: Theme.of(context).primaryColor),
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memoryAvatar = widget.memory.avatar;
    final memoryName = widget.memory.name;
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Hero(
            tag: 'memory_${widget.memory.id}',
            child: Material(
              color: Colors.transparent,
              child: Text(
                _memoryTyping ? _typingText : memoryName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: _memoryTyping ? 16 : 20,
                  color: _memoryTyping ? theme.colorScheme.onSurface.withOpacity(0.6) : theme.primaryColor,
                ),
              ),
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.primaryColor),
            onPressed: () async {
              // 在退出前更新记忆的聊天记录
              final updatedMemory = Memory(
                id: widget.memory.id,
                name: widget.memory.name,
                gender: widget.memory.gender,
                ageGroup: widget.memory.ageGroup,
                personality: widget.memory.personality,
                avatar: widget.memory.avatar,
                creationDate: widget.memory.creationDate,
                chatHistory: _messages,
                uuid: widget.memory.uuid,
              );
              
              // 更新本地存储中的记忆
              final memoriesBox = Hive.box<Memory>('memories');
              await memoriesBox.put(widget.memory.id, updatedMemory);
              print('[DEBUG] 退出前更新记忆的聊天记录');
              
              Navigator.pop(context, true);
            },
          ),
          elevation: 0,
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(8),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final msg = _messages[i];
                    final isUser = msg['sender'] == 'user';
                    final isSystem = msg['sender'] == 'system';
                    final text = (msg['message'] ?? '').toString().trim();

                    if (isSystem) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      );
                    }

                    return AnimatedOpacity(
                      duration: Duration(milliseconds: 300),
                      opacity: 1.0,
                      child: AnimatedSlide(
                        duration: Duration(milliseconds: 300),
                        offset: Offset(0, 0),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isUser)
                                  _buildAvatar(false),
                            if (!isUser) SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser ? theme.primaryColor.withOpacity(0.1) : theme.colorScheme.onSurface.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  text,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: isUser ? theme.primaryColor : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            if (isUser) SizedBox(width: 8),
                            if (isUser)
                                  _buildAvatar(true),
                          ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: _getText('hint'),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: theme.primaryColor),
                          onPressed: _sendMessage,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}