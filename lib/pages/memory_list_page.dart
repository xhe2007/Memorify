import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';
import '../services/api_service.dart';
import 'create_memory_page.dart';
import 'chat_page.dart';
import 'user_profile_page.dart';
import '../providers/locale_provider.dart';
import '../main.dart';
import '../utils/uuid_helper.dart';
import '../config/api_config.dart';
import '../services/local_storage_service.dart';
import 'dart:convert';
import 'dart:io';
import '../utils/custom_page_route.dart';

class MemoryListPage extends StatefulWidget {
  @override
  _MemoryListPageState createState() => _MemoryListPageState();
}

class _MemoryListPageState extends State<MemoryListPage> with RouteAware, SingleTickerProviderStateMixin {
  List<Memory> _memories = [];
  bool _isEditing = false;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _editingAnimation;

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
    _editingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.value = 0.0; // 初始状态为三道杠
    _loadMemories();
    
    // 打印目录结构以便调试
    LocalStorageService.printDirectoryStructure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _animationController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    print('[DEBUG] 返回记忆列表页面，刷新数据');
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      setState(() => _isLoading = true);
      
      final localMemories = LocalStorageService.getMemories();
      print('[DEBUG] 本地存储中的记忆: ${localMemories?.length ?? 0} 条');
      
      if (localMemories != null) {
        for (var memory in localMemories) {
          print('[DEBUG] 加载记忆: ID=${memory.id}, 名称=${memory.name}, 头像=${memory.avatar}');
        }
      }
      
      setState(() {
        _memories = localMemories ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('[DEBUG] 加载失败: $e');
      setState(() {
        _memories = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMemory(String id) async {
    try {
      print('[DEBUG] 开始删除记忆: $id');
      
      await LocalStorageService.deleteMemory(id);
      print('[DEBUG] 记忆已从本地存储删除');
      
      // 刷新列表
      setState(() {
        _memories.removeWhere((m) => m.id == id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('记忆已删除'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    } catch (e) {
      print('[DEBUG] 删除操作失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败，请重试'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Widget _buildMemoryAvatar(String avatarPath) {
    if (avatarPath.isEmpty) {
      return CircleAvatar(
        radius: 60,
        child: Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      );
    }

    return FutureBuilder<String>(
      future: LocalStorageService.getAbsoluteImagePath(avatarPath),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return CircleAvatar(
            radius: 60,
            backgroundImage: FileImage(File(snapshot.data!)),
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            onBackgroundImageError: (exception, stackTrace) {
              print('[DEBUG] 加载头像失败: $exception');
              return;
            },
          );
        }
        return CircleAvatar(
          radius: 60,
          child: Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor),
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        );
      },
    );
  }

  Future<void> _navigateToChatPage(Memory memory) async {
    await Navigator.of(context).push(
      SlidePageRoute(
        page: ChatPage(memory: memory),
      ),
    );
  }

  Future<void> _navigateToCreateMemoryPage() async {
    await Navigator.of(context).push(
      SlidePageRoute(
        page: CreateMemoryPage(),
      ),
    );
  }

  void _navigateToUserProfile() {
    Navigator.of(context).push(
      SlidePageRoute(
        page: UserProfilePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final isEn = locale.isEnglish;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
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
        child: Column(
          children: [
            if (_memories.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.memory,
                        size: 64,
                        color: theme.primaryColor.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        isEn ? 'No memories yet!' : '你还没有创建任何记忆哦！',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: CustomScrollView(
                  physics: BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final m = _memories[index];
                            final hasChat = m.chatHistory != null && m.chatHistory.isNotEmpty;
                            final lastMessage = hasChat
                                ? m.chatHistory.last['message'].toString().trim()
                                : (isEn ? 'Tap to chat with this Memory' : '点击 Memory 开始聊天');

                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 500),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: AnimatedBuilder(
                                      animation: _editingAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: 1.0 - (_editingAnimation.value * 0.03),
                                          child: child,
                                        );
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: AnimatedContainer(
                                          duration: Duration(milliseconds: 300),
                                          transform: Matrix4.identity()
                                            ..setEntry(3, 2, 0.001)
                                            ..rotateX(_editingAnimation.value * 0.05),
                                          transformAlignment: Alignment.center,
                                          child: GestureDetector(
                                            onTap: _isEditing
                                                ? null
                                                : () async {
                                                    await _navigateToChatPage(m);
                                                  },
                                            child: Card(
                                              elevation: 4 * (1 - _editingAnimation.value),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Stack(
                                                children: [
                                                  Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.all(16),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        _buildMemoryAvatar(m.avatar),
                                                        SizedBox(height: 12),
                                                        Text(
                                                          m.name,
                                                          style: theme.textTheme.headlineMedium?.copyWith(
                                                            fontSize: 20,
                                                            color: theme.primaryColor,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                        SizedBox(height: 6),
                                                        Text(
                                                          lastMessage,
                                                          style: theme.textTheme.bodyMedium,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (_isEditing)
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: GestureDetector(
                                                        onTap: () async {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (_) => AlertDialog(
                                                              title: Text(
                                                                isEn ? 'I choose to forget' : '我选择遗忘',
                                                                style: theme.textTheme.headlineMedium,
                                                              ),
                                                              content: Text(
                                                                isEn ? 'Are you sure to forget ${m.name}?' : '你真的要遗忘掉${m.name}吗？',
                                                                style: theme.textTheme.bodyLarge,
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, false),
                                                                  child: Text(isEn ? 'Cancel' : '算了'),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () async {
                                                                    Navigator.pop(context, true);
                                                                    await _deleteMemory(m.id);
                                                                  },
                                                                  child: Text(
                                                                    isEn ? 'Goodbye ${m.name}' : '再见${m.name}',
                                                                    style: TextStyle(color: theme.colorScheme.error),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                        child: Container(
                                                          padding: EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.error.withOpacity(0.1),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: Icon(
                                                            Icons.close,
                                                            size: 20,
                                                            color: theme.colorScheme.error,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: _memories.length,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isEditing
                      ? null
                      : () async {
                          await _navigateToCreateMemoryPage();
                        },
                  style: ElevatedButton.styleFrom(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: _isEditing 
                        ? Theme.of(context).disabledColor 
                        : Theme.of(context).primaryColor,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: Duration(milliseconds: 300),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ) ?? TextStyle(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          child: Icon(
                            Icons.add,
                            key: ValueKey(_isEditing),
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          isEn ? 'Create Memory' : '创建记忆',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}