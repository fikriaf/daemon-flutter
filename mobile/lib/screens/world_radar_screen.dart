import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/chat_engine.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';

class WorldRadarScreen extends StatefulWidget {
  final ChatSession? initialSession;
  const WorldRadarScreen({super.key, this.initialSession});

  @override
  State<WorldRadarScreen> createState() => _WorldRadarScreenState();
}

class _WorldRadarScreenState extends State<WorldRadarScreen> {
  late final ScrollController _chatScrollController;
  late final ChatController _chatController;
  bool _isChatActive = false;

  static const Color greenAccent = Color(0xFF00E676);
  static const Color conflictColor = Color(0xFFFF5252);
  static const Color marketColor = Color(0xFF5BC0BE);
  static const Color newsColor = Color(0xFF42A5F5);
  static const Color disasterColor = Color(0xFFFFB74D);

  final List<Map<String, dynamic>> _alerts = [
    {
      'title': 'Eastern Europe Watch',
      'region': 'Eastern Europe',
      'severity': 'high',
      'time': '2m ago',
    },
    {
      'title': 'Middle East Tensions',
      'region': 'Middle East',
      'severity': 'high',
      'time': '15m ago',
    },
    {
      'title': 'NATO Exercise',
      'region': 'Baltic Sea',
      'severity': 'medium',
      'time': '1h ago',
    },
  ];

  final List<Map<String, dynamic>> _marketData = [
    {
      'name': 'S&P 500',
      'value': '4,927.93',
      'change': '+0.52%',
      'positive': true,
    },
    {
      'name': 'NASDAQ',
      'value': '15,628.95',
      'change': '+0.76%',
      'positive': true,
    },
    {'name': 'DOW', 'value': '38,519.84', 'change': '+0.34%', 'positive': true},
    {
      'name': 'BTC/USD',
      'value': '42,891.32',
      'change': '-1.23%',
      'positive': false,
    },
    {
      'name': 'ETH/USD',
      'value': '2,342.18',
      'change': '+2.15%',
      'positive': true,
    },
  ];

  final List<Map<String, dynamic>> _news = [
    {
      'title': 'EU Summit — Paris',
      'source': 'Reuters',
      'time': '5m ago',
      'category': 'news',
      'region': 'Europe',
    },
    {
      'title': 'Japan Policy Update',
      'source': 'Bloomberg',
      'time': '12m ago',
      'category': 'news',
      'region': 'Asia',
    },
    {
      'title': 'ASEAN Trade Deal',
      'source': 'Financial Times',
      'time': '28m ago',
      'category': 'market',
      'region': 'Asia',
    },
    {
      'title': 'Sydney Fire Alert',
      'source': 'ABC News',
      'time': '35m ago',
      'category': 'disaster',
      'region': 'Australia',
    },
  ];

  final List<Map<String, dynamic>> _trending = [
    {'keyword': 'NATO', 'count': '12.5K', 'trend': 'rising'},
    {'keyword': 'Bitcoin', 'count': '8.2K', 'trend': 'falling'},
    {'keyword': 'Earnings', 'count': '5.1K', 'trend': 'rising'},
    {'keyword': 'AI Chips', 'count': '3.8K', 'trend': 'stable'},
  ];

  @override
  void initState() {
    super.initState();
    _chatScrollController = ScrollController();
    _chatController = ChatController(
      setState: setState,
      scrollController: _chatScrollController,
      onLoginRequired: _onLoginRequired,
    );
    _chatController.loadInitialData();
  }

  @override
  void dispose() {
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

  String _buildContextPrefix() {
    return 'You are an AI assistant in the World Radar section of the Daemon app. '
        'World Radar is a real-time global intelligence dashboard showing live news, '
        'markets, military tracking, flight & ship AIS, earthquakes, and geopolitical data. '
        'Answer the user\'s questions about global events and geopolitics.';
  }

  String _buildContextLabel() {
    return 'World Radar · live dashboard';
  }

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
        title: _isChatActive
            ? Text(
                'World Radar Chat',
                style: Theme.of(context).textTheme.titleLarge,
              )
            : Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: greenAccent,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'World Radar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
      ),
      body: _isChatActive ? _buildChatView() : _buildDashboardView(),
      bottomNavigationBar: ChatInputBar(
        controller: _chatController,
        contextPrefixBuilder: _buildContextPrefix,
        contextLabelBuilder: _buildContextLabel,
        contextLabel: _buildContextLabel(),
        contextIcon: Icons.radar,
        onBeforeSubmit: () async {
          if (mounted) setState(() => _isChatActive = true);
        },
      ),
    );
  }

  Widget _buildDashboardView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (isTablet) {
      return Row(children: [Expanded(child: _buildDataPanels())]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveAlerts(),
          const SizedBox(height: 20),
          _buildMarketPulse(),
          const SizedBox(height: 20),
          _buildBreakingNews(),
          const SizedBox(height: 20),
          _buildTrending(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    Color color,
    String? badge,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveAlerts() {
    final highCount = _alerts.where((a) => a['severity'] == 'high').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Live Alerts',
          conflictColor,
          '$highCount HIGH',
          Icons.warning_amber,
        ),
        ...List.generate(_alerts.length, (i) {
          final alert = _alerts[i];
          final isHigh = alert['severity'] == 'high';
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHigh
                    ? conflictColor.withValues(alpha: 0.3)
                    : AppTheme.borderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isHigh ? conflictColor : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert['title'],
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${alert['region']} · ${alert['time']}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMarketPulse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Market Pulse',
          marketColor,
          'LIVE',
          Icons.trending_up,
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            children: List.generate(_marketData.length, (i) {
              final m = _marketData[i];
              final isPositive = m['positive'] as bool;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m['name'],
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          m['value'],
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isPositive ? greenAccent : conflictColor,
                              size: 12,
                            ),
                            Text(
                              m['change'],
                              style: TextStyle(
                                color: isPositive ? greenAccent : conflictColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakingNews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Breaking News',
          newsColor,
          '${_news.length}',
          Icons.newspaper,
        ),
        ...List.generate(_news.length, (i) {
          final n = _news[i];
          Color catColor;
          switch (n['category']) {
            case 'conflict':
              catColor = conflictColor;
              break;
            case 'market':
              catColor = marketColor;
              break;
            case 'disaster':
              catColor = disasterColor;
              break;
            default:
              catColor = newsColor;
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n['title'],
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${n['source']} · ${n['time']} · ${n['region']}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrending() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Trending',
          disasterColor,
          null,
          Icons.local_fire_department,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_trending.length, (i) {
            final t = _trending[i];
            Color trendColor;
            IconData trendIcon;
            switch (t['trend']) {
              case 'rising':
                trendColor = greenAccent;
                trendIcon = Icons.arrow_upward;
                break;
              case 'falling':
                trendColor = conflictColor;
                trendIcon = Icons.arrow_downward;
                break;
              default:
                trendColor = AppTheme.textSecondary;
                trendIcon = Icons.remove;
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: trendColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t['keyword'],
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t['count'],
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(trendIcon, color: trendColor, size: 10),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDataPanels() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveAlerts(),
          const SizedBox(height: 20),
          _buildMarketPulse(),
          const SizedBox(height: 20),
          _buildBreakingNews(),
          const SizedBox(height: 20),
          _buildTrending(),
        ],
      ),
    );
  }

  Widget _buildChatView() {
    return ChatMessagesView(
      messages: _chatController.messages,
      sources: _chatController.sources,
      isSearching: _chatController.isSearching,
      scrollController: _chatScrollController,
      contextSummary: _buildContextLabel(),
      contextIcon: Icons.radar,
      onEdit: (idx, newText) => _chatController.editMessage(
        idx,
        newText,
        contextPrefix: _buildContextPrefix(),
        contextLabel: _buildContextLabel(),
      ),
      onDelete: (idx) => _chatController.deleteMessage(idx),
      onLikeChanged: (idx, state) =>
          setState(() => _chatController.messages[idx].likeState = state),
      onShare: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied to clipboard'))),
    );
  }
}
