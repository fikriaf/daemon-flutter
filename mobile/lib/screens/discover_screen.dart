import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar_drawer.dart';
import '../theme/app_theme.dart';
import '../widgets/modals.dart';
import '../services/provider.dart';
import '../services/agent_service.dart';
import '../services/discover_service.dart';
import '../services/error_handler.dart' show isAuthError;
import '../widgets/skeleton.dart';
import '../widgets/chat_engine.dart';

class DiscoverScreen extends StatefulWidget {
  final ChatSession? initialSession;
  const DiscoverScreen({super.key, this.initialSession});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'top';

  List<Article> _articles = [];
  bool _isLoading = true;

  // ── Chat ──────────────────────────────────────────────────────────────────
  late final ScrollController _chatScrollController;
  late final ChatController _chatController;
  bool _isChatActive = false;

  final List<Map<String, String>> _categories = [
    {'id': 'top', 'name': 'Top'},
    {'id': 'tech', 'name': 'Tech & Science'},
    {'id': 'finance', 'name': 'Finance'},
    {'id': 'arts', 'name': 'Arts & Culture'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    _chatScrollController = ScrollController();
    _chatController = ChatController(
      setState: setState,
      scrollController: _chatScrollController,
      onLoginRequired: _onLoginRequired,
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
    );
    _chatController.loadInitialData();

    _loadArticles();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _chatScrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _onLoginRequired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please login to continue'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () => context.push('/login'),
        ),
      ),
    );
  }

  void _onSessionTap(ChatSession session) {
    setState(() => _isChatActive = true);
    _chatController.loadSession(session);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedCategory = _categories[_tabController.index]['id']!;
        // Reset chat when switching tabs so context stays relevant
        if (_isChatActive) {
          _isChatActive = false;
          _chatController.messages.clear();
          _chatController.sources.clear();
        }
      });
      _loadArticles();
    }
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);

    try {
      final data = await apiProvider.discoverService
          .getArticles(category: _selectedCategory);
      if (mounted) {
        setState(() {
          _articles = data.articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading articles: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (isAuthError(e)) {
          _onLoginRequired();
        }
      }
    }
  }

  /// Builds a system prompt describing the currently visible articles.
  String _buildContextPrefix() {
    final categoryName =
        _categories.firstWhere((c) => c['id'] == _selectedCategory)['name'] ??
            _selectedCategory;
    final buf = StringBuffer();
    buf.writeln(
        'You are an AI assistant in the Discover section of the Daemon app. '
        'The user is currently browsing the "$categoryName" news category. '
        'Here are the current articles displayed:');
    for (int i = 0; i < _articles.length; i++) {
      final a = _articles[i];
      buf.writeln(
          '${i + 1}. "${a.title}" — ${a.summary} (Source: ${a.source})');
    }
    buf.writeln('\nAnswer the user\'s questions with this context in mind.');
    return buf.toString();
  }

  /// Short label shown in the context indicator and summary card.
  String _buildContextLabel() {
    final categoryName =
        _categories.firstWhere((c) => c['id'] == _selectedCategory)['name'] ??
            _selectedCategory;
    final count = _articles.length;
    return '$categoryName · $count article${count == 1 ? '' : 's'}';
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} min ago';
    return 'Just now';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SidebarDrawer(onSessionTap: _onSessionTap),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => _isChatActive
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _isChatActive = false),
                )
              : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
        ),
        title: Text(
          _isChatActive ? 'Discover Chat' : 'Discover',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        bottom: _isChatActive
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppTheme.textPrimary,
                indicatorWeight: 2,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: _categories.map((c) => Tab(text: c['name'])).toList(),
              ),
      ),
      body: _isChatActive ? _buildChatView() : _buildArticlesView(),
      bottomNavigationBar: ChatInputBar(
        controller: _chatController,
        contextPrefix: _buildContextPrefix(),
        contextLabel: _buildContextLabel(),
        contextIcon: Icons.article_outlined,
        onBeforeSubmit: _isChatActive ? null : () async {
          setState(() => _isChatActive = true);
        },
      ),
    );
  }

  Widget _buildArticlesView() {
    return _isLoading
        ? const _DiscoverSkeleton()
        : TabBarView(
            controller: _tabController,
            children: _categories.map((_) => _buildTabContent()).toList(),
          );
  }

  Widget _buildChatView() {
    return ChatMessagesView(
      messages: _chatController.messages,
      sources: _chatController.sources,
      isSearching: _chatController.isSearching,
      scrollController: _chatScrollController,
      contextSummary: _buildContextLabel(),
      contextIcon: Icons.article_outlined,
      onEdit: (idx, newText) => _chatController.editMessage(
        idx,
        newText,
        contextPrefix: _buildContextPrefix(),
        contextLabel: _buildContextLabel(),
      ),
      onDelete: (idx) => _chatController.deleteMessage(idx),
      onLikeChanged: (idx, state) {
        setState(() => _chatController.messages[idx].likeState = state);
      },
      onShare: (text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      },
    );
  }

  Widget _buildTabContent() {
    if (_articles.isEmpty) {
      return const Center(child: Text('No articles found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final article = _articles[index];
        return _DiscoverCard(
          title: article.title,
          source: article.source,
          time: _getTimeAgo(article.publishedAt),
          imageUrl: article.imageUrl ?? '',
          url: article.url,
        );
      },
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: 4,
      itemBuilder: (context, _) => Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: double.infinity, height: 160, radius: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 200, height: 14),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 120, height: 11),
                      SkeletonBox(width: 48, height: 11),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Article Card ─────────────────────────────────────────────────────────────

class _DiscoverCard extends StatelessWidget {
  final String title;
  final String source;
  final String time;
  final String imageUrl;
  final String url;

  const _DiscoverCard({
    required this.title,
    required this.source,
    required this.time,
    required this.imageUrl,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  color: AppTheme.borderLight,
                  child: const Center(
                    child: Icon(Icons.image_not_supported,
                        color: AppTheme.textSecondary),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).primaryTextTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppTheme.border,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.language,
                              size: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$source • $time',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bookmark_border,
                              size: 20, color: AppTheme.textSecondary),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.more_horiz,
                              size: 20, color: AppTheme.textSecondary),
                          onPressed: () => Modals.showThreadMenu(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
