import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/skeleton.dart';
import '../theme/app_theme.dart';
import '../services/provider.dart';
import '../services/agent_service.dart';
import '../services/finance_service.dart' as fs;
import '../services/error_handler.dart' show isAuthError;
import '../widgets/chat_engine.dart';

class FinanceScreen extends StatefulWidget {
  final ChatSession? initialSession;
  const FinanceScreen({super.key, this.initialSession});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  fs.FinanceData? _financeData;
  fs.FinanceAnalysis? _analysis;
  bool _isLoading = true;
  bool _isLoadingAnalysis = false;

  fs.EarningsData? _earningsData;
  fs.PredictionsData? _predictionsData;
  fs.ScreenerData? _screenerData;
  bool _isLoadingEarnings = false;
  bool _isLoadingPredictions = false;
  bool _isLoadingScreener = false;

  // ── Chat ──────────────────────────────────────────────────────────────────
  late final ScrollController _chatScrollController;
  late final ChatController _chatController;
  bool _isChatActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _chatScrollController = ScrollController();
    _chatController = ChatController(
      setState: setState,
      scrollController: _chatScrollController,
      onLoginRequired: _onLoginRequired,
    );
    _chatController.loadInitialData();

    _tabController.addListener(() {
      if (_tabController.index == 2) _loadEarnings();
      if (_tabController.index == 3) _loadPredictions();
      if (_tabController.index == 4) _loadScreener();
    });

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatScrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _onSessionTap(ChatSession session) {
    setState(() => _isChatActive = true);
    _chatController.loadSession(session);
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await apiProvider.financeService.getMarketData();
      if (mounted) {
        setState(() {
          _financeData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading finance: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (isAuthError(e)) {
          _onLoginRequired();
        }
      }
    }
  }

  Future<void> _loadAnalysis() async {
    if (_isLoadingAnalysis) return;
    setState(() => _isLoadingAnalysis = true);
    try {
      final analysis = await apiProvider.financeService.getFinanceAnalysis();
      if (mounted) {
        setState(() {
          _analysis = analysis;
          _isLoadingAnalysis = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAnalysis = false);
    }
  }

  Future<void> _loadEarnings() async {
    if (_isLoadingEarnings || _earningsData != null) return;
    setState(() => _isLoadingEarnings = true);
    try {
      final data = await apiProvider.financeService.getEarnings();
      if (mounted) setState(() { _earningsData = data; _isLoadingEarnings = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingEarnings = false);
    }
  }

  Future<void> _loadPredictions() async {
    if (_isLoadingPredictions || _predictionsData != null) return;
    setState(() => _isLoadingPredictions = true);
    try {
      final data = await apiProvider.financeService.getPredictions();
      if (mounted) setState(() { _predictionsData = data; _isLoadingPredictions = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPredictions = false);
    }
  }

  Future<void> _loadScreener() async {
    if (_isLoadingScreener || _screenerData != null) return;
    setState(() => _isLoadingScreener = true);
    try {
      final data = await apiProvider.financeService.getScreener();
      if (mounted) setState(() { _screenerData = data; _isLoadingScreener = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingScreener = false);
    }
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
              ? Text('Finance Chat',
                  style: Theme.of(context).textTheme.titleLarge)
              : Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search ticker...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPlaceholder,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
          actions: _isChatActive
              ? []
              : [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppTheme.textSecondary),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share, color: AppTheme.textSecondary),
                    onPressed: () {},
                  ),
                ],
          bottom: _isChatActive
              ? null
              : TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppTheme.textPrimary,
                  indicatorWeight: 2,
                  labelColor: AppTheme.textPrimary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  tabs: [
                    Tab(child: Row(children: [Icon(Icons.flag, size: 16), SizedBox(width: 4), Text('US Markets'), SizedBox(width: 4), Icon(Icons.keyboard_arrow_down, size: 16)])),
                    Tab(text: 'Crypto'),
                    Tab(text: 'Earnings'),
                    Tab(text: 'Predictions'),
                    Tab(text: 'Screener'),
                  ],
                ),
        ),
        body: _isChatActive
            ? _buildChatView()
            : _isLoading
                ? const _FinanceSkeleton()
                : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: US Markets
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      children: [
                        // Fear & Greed Index
                        _FearGreedGauge(
                          value: _financeData?.sentiment.fearGreedIndex ?? 50,
                          label: _financeData?.sentiment.label ?? 'Neutral',
                          isBullish: _financeData?.sentiment.overall == 'bullish',
                        ),
                        const SizedBox(height: 20),

                        // Market Status Banner
                        _MarketStatusBanner(
                          isOpen: _financeData?.marketStatus?.isOpen ?? false,
                          nextEvent: _financeData?.marketStatus?.nextEvent ?? 'opens',
                          nextEventTime: _financeData?.marketStatus?.nextEventTime ?? '9:30 AM ET',
                        ),
                        const SizedBox(height: 20),

                        // Index Movements
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Index Movements', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            Row(
                              children: [
                                Icon(
                                  _financeData?.sentiment.overall == 'bullish' ? Icons.trending_up : Icons.trending_down,
                                  color: _financeData?.sentiment.overall == 'bullish' ? Colors.green : Colors.redAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_financeData?.sentiment.label ?? 'Neutral'} Sentiment',
                                  style: TextStyle(
                                    color: _financeData?.sentiment.overall == 'bullish' ? Colors.green : Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.35,
                          children: _financeData?.indices.map((idx) => _IndexCard(
                            title: idx.name,
                            symbol: idx.symbol,
                            value: _formatNumber(idx.value),
                            change: idx.change.toStringAsFixed(2),
                            pctChange: '${idx.pctChange >= 0 ? '+' : ''}${idx.pctChange.toStringAsFixed(2)}%',
                            isUp: idx.trend == 'up',
                          )).toList() ?? [],
                        ),

                        const SizedBox(height: 24),

                        // AI Analysis
                        _SectionHeader(
                          title: 'AI Market Analysis',
                          subtitle: 'Updated hourly',
                          icon: Icons.auto_awesome,
                          iconColor: Colors.purple,
                        ),
                        const SizedBox(height: 12),
                        _AIMarketAnalysisWidget(
                          analysis: _analysis,
                          isLoading: _isLoadingAnalysis,
                          onLoad: _loadAnalysis,
                        ),

                        const SizedBox(height: 24),

                        // Market News
                        _SectionHeader(
                          title: 'Market News',
                          subtitle: 'Latest',
                          icon: Icons.newspaper,
                          iconColor: Colors.blue,
                        ),
                        const SizedBox(height: 12),

                        if (_financeData?.marketSummary != null)
                          ...(_financeData!.marketSummary.take(5).map((news) => _NewsCard(
                            title: news.title,
                            source: news.source,
                            timeAgo: _getTimeAgo(news.publishedAt),
                            imageUrl: news.imageUrl,
                            url: news.url,
                          ))),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),

                  // Tab 1: Crypto
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      children: [
                        _SectionHeader(
                          title: 'Cryptocurrency',
                          subtitle: 'Live prices',
                          icon: Icons.currency_bitcoin,
                          iconColor: const Color(0xFFF7931A),
                        ),
                        const SizedBox(height: 12),

                        if (_financeData?.crypto != null)
                          ...(_financeData!.crypto.map((crypto) => _CryptoTile(
                            symbol: crypto.symbol,
                            name: crypto.name,
                            price: crypto.price,
                            change24h: crypto.change24h,
                            trend: crypto.trend,
                          ))),

                        const SizedBox(height: 24),

                        // AI Analysis on Crypto tab too
                        _SectionHeader(
                          title: 'AI Crypto Analysis',
                          subtitle: 'Updated hourly',
                          icon: Icons.auto_awesome,
                          iconColor: Colors.purple,
                        ),
                        const SizedBox(height: 12),
                        _AIMarketAnalysisWidget(
                          analysis: _analysis,
                          isLoading: _isLoadingAnalysis,
                          onLoad: _loadAnalysis,
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),

                  // Tab 2: Earnings
                  _EarningsTab(
                    data: _earningsData,
                    isLoading: _isLoadingEarnings,
                    onRetry: _loadEarnings,
                  ),

                  // Tab 3: Predictions
                  _PredictionsTab(
                    data: _predictionsData,
                    isLoading: _isLoadingPredictions,
                    onRetry: _loadPredictions,
                  ),

                  // Tab 4: Screener
                  _ScreenerTab(
                    data: _screenerData,
                    isLoading: _isLoadingScreener,
                    onRetry: _loadScreener,
                  ),
                ],
              ),
        bottomNavigationBar: ChatInputBar(
          controller: _chatController,
          contextPrefix: _buildContextPrefix(),
          contextLabel: _buildContextLabel(),
          contextIcon: Icons.show_chart_rounded,
          onBeforeSubmit: _isChatActive ? null : () async {
            setState(() => _isChatActive = true);
          },
        ),
      );
  }

  /// Builds a system prompt describing the currently visible finance data.
  String _buildContextPrefix() {
    final tab = _tabController.index;
    final buf = StringBuffer();
    buf.writeln(
        'You are an AI assistant in the Finance section of the Daemon app. ');

    if (tab == 0) {
      // US Markets
      buf.writeln('The user is viewing the US Markets tab.');
      if (_financeData != null) {
        final s = _financeData!.sentiment;
        buf.writeln(
            'Market sentiment: ${s.overall} (Fear & Greed: ${s.fearGreedIndex} — ${s.label}).');
        final ms = _financeData!.marketStatus;
        if (ms != null) {
          buf.writeln(
              'Market status: ${ms.isOpen ? 'Open' : 'Closed'}. Next event: ${ms.nextEvent} at ${ms.nextEventTime}.');
        }
        buf.writeln('Index data:');
        for (final idx in _financeData!.indices) {
          buf.writeln(
              '  ${idx.name} (${idx.symbol}): ${idx.value.toStringAsFixed(2)} '
              '${idx.pctChange >= 0 ? '+' : ''}${idx.pctChange.toStringAsFixed(2)}% (${idx.trend})');
        }
        if (_financeData!.marketSummary.isNotEmpty) {
          buf.writeln('Recent market news:');
          for (final n in _financeData!.marketSummary.take(5)) {
            buf.writeln('  - "${n.title}" (${n.source})');
          }
        }
      }
    } else if (tab == 1) {
      // Crypto
      buf.writeln('The user is viewing the Crypto tab.');
      if (_financeData?.crypto != null) {
        buf.writeln('Current crypto prices:');
        for (final c in _financeData!.crypto) {
          buf.writeln(
              '  ${c.name} (${c.symbol}): \$${c.price.toStringAsFixed(2)} '
              '${c.change24h >= 0 ? '+' : ''}${c.change24h.toStringAsFixed(2)}% 24h (${c.trend})');
        }
      }
    } else if (tab == 2) {
      buf.writeln('The user is viewing the Earnings tab.');
      if (_earningsData != null) {
        buf.writeln('Upcoming earnings this week:');
        for (final e in _earningsData!.earningsCalendar.take(5)) {
          buf.writeln('  ${e.ticker} (${e.company}): ${e.reportDate} ${e.reportTime}');
        }
      }
    } else if (tab == 3) {
      buf.writeln('The user is viewing the AI Predictions tab.');
      if (_predictionsData != null) {
        for (final p in _predictionsData!.predictions.take(5)) {
          buf.writeln('  ${p.ticker}: current \$${p.currentPrice.toStringAsFixed(2)}, target \$${p.targetPrice.toStringAsFixed(2)} (${p.upsidePct >= 0 ? '+' : ''}${p.upsidePct.toStringAsFixed(1)}%), rating: ${p.analystRating}');
        }
      }
    } else if (tab == 4) {
      buf.writeln('The user is viewing the Stock Screener tab.');
      if (_screenerData != null) {
        buf.writeln('Top gainers: ${_screenerData!.topGainers.take(3).map((s) => '${s.ticker} +${s.changePct.toStringAsFixed(2)}%').join(', ')}');
        buf.writeln('Top losers: ${_screenerData!.topLosers.take(3).map((s) => '${s.ticker} ${s.changePct.toStringAsFixed(2)}%').join(', ')}');
      }
    } else {
      buf.writeln('The user is viewing a placeholder Finance tab (tab index $tab).');
    }

    buf.writeln('\nAnswer the user\'s financial questions with this context in mind.');
    return buf.toString();
  }

  /// Short label for the context indicator / summary card.
  String _buildContextLabel() {
    switch (_tabController.index) {
      case 0:
        final count = _financeData?.indices.length ?? 0;
        final sentiment = _financeData?.sentiment.label;
        return 'US Markets · $count indices${sentiment != null ? ' · $sentiment' : ''}';
      case 1:
        final count = _financeData?.crypto.length ?? 0;
        return 'Crypto · $count asset${count == 1 ? '' : 's'}';
      case 2:
        final upcoming = _earningsData?.earningsCalendar.length ?? 0;
        final recent = _earningsData?.recentReports.length ?? 0;
        return 'Earnings · $upcoming upcoming, $recent recent';
      case 3:
        final count = _predictionsData?.predictions.length ?? 0;
        return 'AI Predictions · $count stock${count == 1 ? '' : 's'}';
      case 4:
        final gainers = _screenerData?.topGainers.length ?? 0;
        final losers = _screenerData?.topLosers.length ?? 0;
        return 'Screener · $gainers gainers, $losers losers';
      default:
        return 'Finance';
    }
  }

  Widget _buildChatView() {
    return ChatMessagesView(
      messages: _chatController.messages,
      sources: _chatController.sources,
      isSearching: _chatController.isSearching,
      scrollController: _chatScrollController,
      contextSummary: _buildContextLabel(),
      contextIcon: Icons.show_chart_rounded,
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
      onShare: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      },
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }
    return value.toStringAsFixed(2);
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _FearGreedGauge extends StatelessWidget {
  final int value;
  final String label;
  final bool isBullish;

  const _FearGreedGauge({
    required this.value,
    required this.label,
    required this.isBullish,
  });

  Color get _gaugeColor {
    if (value <= 25) return Colors.red;
    if (value <= 45) return Colors.orange;
    if (value <= 55) return Colors.yellow;
    if (value <= 75) return Colors.lightGreen;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gaugeColor.withValues(alpha: 0.2),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gaugeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Gauge Arc
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _GaugePainter(value: value, color: _gaugeColor),
              child: Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _gaugeColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fear & Greed Index',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: _gaugeColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value < 50 ? 'Extreme Fear - Potential Buying Opportunity' : 
                  value > 50 ? 'Greed Increasing - Stay Cautious' : 'Neutral Market',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isBullish ? Icons.trending_up : Icons.trending_down,
            color: _gaugeColor,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int value;
  final Color color;

  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Background arc
    final bgPaint = Paint()
      ..color = AppTheme.borderLight
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14,
      3.14,
      false,
      bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (value / 100) * 3.14;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MarketStatusBanner extends StatelessWidget {
  final bool isOpen;
  final String nextEvent;
  final String nextEventTime;

  const _MarketStatusBanner({
    required this.isOpen,
    required this.nextEvent,
    required this.nextEventTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOpen ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isOpen ? Colors.green : Colors.orange).withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOpen ? 'US Markets Open' : 'US Markets Closed',
              style: TextStyle(
                color: isOpen ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$nextEvent $nextEventTime',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexCard extends StatelessWidget {
  final String title;
  final String symbol;
  final String value;
  final String change;
  final String pctChange;
  final bool isUp;

  const _IndexCard({
    required this.title,
    required this.symbol,
    required this.value,
    required this.change,
    required this.pctChange,
    required this.isUp,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUp ? Colors.green : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.surface, color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    Text(symbol,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: color),
                    const SizedBox(width: 2),
                    Text(pctChange, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text('${isUp ? '+' : ''}$change',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          const SizedBox(height: 4),
          // Mini sparkline
          SizedBox(
            height: 18,
            child: CustomPaint(size: const Size(double.infinity, 18), painter: _SparklinePainter(color: color)),
          ),
        ],
      ),
    );
  }
}

class _CryptoTile extends StatelessWidget {
  final String symbol;
  final String name;
  final double price;
  final double change24h;
  final String trend;

  const _CryptoTile({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change24h,
    required this.trend,
  });

  Color get _trendColor => trend == 'up' ? Colors.green : Colors.redAccent;
  IconData get _cryptoIcon {
    switch (symbol) {
      case 'BTC': return Icons.currency_bitcoin;
      case 'ETH': return Icons.memory;
      case 'SOL': return Icons.bolt;
      default: return Icons.currency_exchange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUp = trend == 'up';
    final color = _trendColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surface,
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(_cryptoIcon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.borderLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(symbol, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('\$${_formatPrice(price)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 16, color: color),
                          Text(
                            '${change24h >= 0 ? '+' : ''}${change24h.toStringAsFixed(2)}%',
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Mini chart placeholder
          SizedBox(
            width: 50,
            height: 30,
            child: CustomPaint(painter: _SparklinePainter(color: color)),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }
    return price.toStringAsFixed(2);
  }
}

class _AIMarketAnalysisWidget extends StatelessWidget {
  final fs.FinanceAnalysis? analysis;
  final bool isLoading;
  final VoidCallback onLoad;

  const _AIMarketAnalysisWidget({
    required this.analysis,
    required this.isLoading,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    if (analysis == null && !isLoading) {
      // Lazy load — show a prompt button
      return GestureDetector(
        onTap: onLoad,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generate AI Analysis', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text('Tap to analyze current market conditions', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
            ],
          ),
        ),
      );
    }

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple)),
            const SizedBox(width: 12),
            Text('Analyzing market conditions...', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    final a = analysis!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withValues(alpha: 0.08), AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
              const SizedBox(width: 6),
              Text('AI Analysis', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.purple, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                'Valid until ${_formatTime(a.validUntil)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a.analysis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, color: AppTheme.textPrimary),
          ),
          if (a.modelUsed != null) ...[
            const SizedBox(height: 10),
            Text(
              'Model: ${a.modelUsed!.split('/').last.split(':').first}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _NewsCard extends StatelessWidget {
  final String title;
  final String source;
  final String timeAgo;
  final String? imageUrl;
  final String? url;

  const _NewsCard({
    required this.title,
    required this.source,
    required this.timeAgo,
    this.imageUrl,
    this.url,
  });

  Color _sourceColor(String source) {
    const colors = {
      'reuters.com': Color(0xFFFF6B35),
      'bloomberg.com': Color(0xFF5B6ECF),
      'cnbc.com': Color(0xFF003087),
      'marketwatch.com': Color(0xFF00A651),
      'wsj.com': Color(0xFF0062A8),
      'finance.yahoo.com': Color(0xFF7B00D4),
      'seekingalpha.com': Color(0xFF2563EB),
      'coindesk.com': Color(0xFF1652F0),
      'cointelegraph.com': Color(0xFF02AEF1),
      'forbes.com': Color(0xFF0032A0),
      'ft.com': Color(0xFFFF6B35),
      'businessinsider.com': Color(0xFF1877F2),
    };
    final key = source.toLowerCase();
    return colors[key] ?? colors.entries
        .firstWhere((e) => key.contains(e.key.split('.').first), orElse: () => const MapEntry('', Color(0xFF2563EB)))
        .value;
  }

  String _faviconUrl(String source) =>
      'https://www.google.com/s2/favicons?domain=$source&sz=64';

  @override
  Widget build(BuildContext context) {
    final accent = _sourceColor(source);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Article image (full-width) ──────────────────────────
          if (hasImage)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => _FallbackBanner(color: accent, source: source),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: accent.withValues(alpha: 0.08),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                        color: accent,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            // Fallback banner with favicon when no article image
            _FallbackBanner(color: accent, source: source),

          // ── Text content ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Favicon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.network(
                        _faviconUrl(source),
                        width: 14,
                        height: 14,
                        errorBuilder: (_, e, s) => Icon(
                          Icons.language,
                          size: 14,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        source,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.open_in_new, size: 12, color: AppTheme.textSecondary),
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

// Shown when article has no image — gradient banner with favicon centered
class _FallbackBanner extends StatelessWidget {
  final Color color;
  final String source;

  const _FallbackBanner({required this.color, required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            'https://www.google.com/s2/favicons?domain=$source&sz=128',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (_, e, s) => Icon(
              Icons.article_outlined,
              size: 32,
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  _SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width, size.height * 0.3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EarningsTab extends StatelessWidget {
  final fs.EarningsData? data;
  final bool isLoading;
  final VoidCallback onRetry;

  const _EarningsTab({required this.data, required this.isLoading, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No earnings data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // AI Summary card
        if (data!.aiSummary != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.withValues(alpha: 0.12), AppTheme.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
                    const SizedBox(width: 6),
                    Text('AI Earnings Summary', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.purple, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(data!.aiSummary!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Upcoming Earnings
        _SectionHeader(
          title: 'Upcoming Earnings',
          subtitle: '${data!.earningsCalendar.length} this week',
          icon: Icons.event,
          iconColor: AppTheme.accentLink,
        ),
        const SizedBox(height: 12),
        ...data!.earningsCalendar.map((e) => _EarningsCard(entry: e)),

        const SizedBox(height: 24),

        // Recent Reports
        _SectionHeader(
          title: 'Recent Reports',
          subtitle: '${data!.recentReports.length} reported',
          icon: Icons.bar_chart,
          iconColor: Colors.green,
        ),
        const SizedBox(height: 12),
        ...data!.recentReports.map((e) => _EarningsCard(entry: e)),

        const SizedBox(height: 100),
      ],
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final fs.EarningsEntry entry;
  const _EarningsCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isReported = entry.status == 'reported';
    final hasSurprise = entry.surprisePct != null;
    final surprisePositive = (entry.surprisePct ?? 0) >= 0;
    final surpriseColor = surprisePositive ? Colors.green : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          // Ticker badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentLink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.ticker,
              style: const TextStyle(color: AppTheme.accentLink, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          // Company + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.company,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (!isReported) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLink.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(entry.reportDate, style: const TextStyle(color: AppTheme.accentLink, fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                      Text(entry.reportTime, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                    ] else ...[
                      Text('EPS Est: ${entry.estimateEps?.toStringAsFixed(2) ?? 'N/A'}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                      if (entry.actualEps != null) ...[
                        const SizedBox(width: 8),
                        Text('Actual: ${entry.actualEps!.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: (entry.actualEps! >= (entry.estimateEps ?? 0)) ? Colors.green : Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Surprise badge for reported
          if (isReported && hasSurprise)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: surpriseColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${surprisePositive ? '+' : ''}${entry.surprisePct!.toStringAsFixed(1)}%',
                style: TextStyle(color: surpriseColor, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            )
          else if (!isReported && entry.estimateEps != null)
            Text(
              'Est EPS\n\$${entry.estimateEps!.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.right,
            ),
        ],
      ),
    );
  }
}

// ─── Predictions Tab ─────────────────────────────────────────────────────────

class _PredictionsTab extends StatelessWidget {
  final fs.PredictionsData? data;
  final bool isLoading;
  final VoidCallback onRetry;

  const _PredictionsTab({required this.data, required this.isLoading, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No predictions data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Market Outlook card
        if (data!.marketPrediction != null) ...[
          _MarketOutlookCard(mp: data!.marketPrediction!),
          const SizedBox(height: 24),
        ],

        _SectionHeader(
          title: 'Stock Predictions',
          subtitle: '${data!.predictions.length} stocks',
          icon: Icons.trending_up,
          iconColor: Colors.green,
        ),
        const SizedBox(height: 12),
        ...data!.predictions.map((p) => _PredictionCard(prediction: p)),

        const SizedBox(height: 100),
      ],
    );
  }
}

class _MarketOutlookCard extends StatelessWidget {
  final fs.MarketPrediction mp;
  const _MarketOutlookCard({required this.mp});

  @override
  Widget build(BuildContext context) {
    final isUp = mp.upsidePct >= 0;
    final color = isUp ? Colors.green : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.08), AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text('S&P 500 Market Outlook', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(mp.timeframe, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                mp.sp500Current.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Icon(isUp ? Icons.arrow_forward : Icons.arrow_forward, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                mp.sp500Target.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isUp ? '+' : ''}${mp.upsidePct.toStringAsFixed(1)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (mp.aiOutlook != null) ...[
            const SizedBox(height: 10),
            Text(mp.aiOutlook!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final fs.StockPrediction prediction;
  const _PredictionCard({required this.prediction});

  Color _ratingColor(String rating) {
    final r = rating.toLowerCase();
    if (r.contains('strong buy') || r.contains('strong_buy')) return Colors.green;
    if (r.contains('buy')) return Colors.green;
    if (r.contains('hold')) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final isUp = prediction.upsidePct >= 0;
    final color = isUp ? Colors.green : Colors.redAccent;
    final ratingColor = _ratingColor(prediction.analystRating);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Ticker
              Text(prediction.ticker, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(prediction.company,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              // Analyst rating badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ratingColor.withValues(alpha: 0.3)),
                ),
                child: Text(prediction.analystRating, style: TextStyle(color: ratingColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Price row
          Row(
            children: [
              Text(
                '\$${prediction.currentPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '\$${prediction.targetPrice.toStringAsFixed(2)}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${isUp ? '+' : ''}${prediction.upsidePct.toStringAsFixed(1)}%',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              if (prediction.analystCount != null) ...[
                const Spacer(),
                Text('${prediction.analystCount} analysts',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Confidence bar
          Row(
            children: [
              Text('Confidence', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: prediction.confidence,
                    minHeight: 4,
                    backgroundColor: AppTheme.borderLight,
                    color: AppTheme.accentLink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(prediction.confidence * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
          // AI rationale
          if (prediction.aiRationale != null) ...[
            const SizedBox(height: 8),
            Text(
              prediction.aiRationale!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Screener Tab ─────────────────────────────────────────────────────────────

class _ScreenerTab extends StatefulWidget {
  final fs.ScreenerData? data;
  final bool isLoading;
  final VoidCallback onRetry;

  const _ScreenerTab({required this.data, required this.isLoading, required this.onRetry});

  @override
  State<_ScreenerTab> createState() => _ScreenerTabState();
}

class _ScreenerTabState extends State<_ScreenerTab> {
  int _selectedSection = 0; // 0=Gainers, 1=Losers, 2=Active

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_list, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No screener data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final data = widget.data!;
    final List<fs.ScreenerStock> stocks = _selectedSection == 0
        ? data.topGainers
        : _selectedSection == 1
            ? data.topLosers
            : data.mostActive;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Sector performance horizontal scroll
        _SectionHeader(
          title: 'Sector Performance',
          subtitle: 'Today',
          icon: Icons.pie_chart_outline,
          iconColor: AppTheme.accentLink,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: data.sectorPerformance.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final sp = data.sectorPerformance[index];
              final isUp = sp.trend == 'up' || sp.changePct >= 0;
              final color = isUp ? Colors.green : Colors.redAccent;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sp.sector, style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 5),
                    Text(
                      '${isUp ? '+' : ''}${sp.changePct.toStringAsFixed(2)}%',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Section toggle
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              _ToggleBtn(label: 'Gainers', selected: _selectedSection == 0, onTap: () => setState(() => _selectedSection = 0)),
              _ToggleBtn(label: 'Losers', selected: _selectedSection == 1, onTap: () => setState(() => _selectedSection = 1)),
              _ToggleBtn(label: 'Active', selected: _selectedSection == 2, onTap: () => setState(() => _selectedSection = 2)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Stock list
        ...stocks.map((s) => _ScreenerStockRow(stock: s)),

        const SizedBox(height: 100),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentLink.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppTheme.accentLink : AppTheme.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenerStockRow extends StatelessWidget {
  final fs.ScreenerStock stock;
  const _ScreenerStockRow({required this.stock});

  @override
  Widget build(BuildContext context) {
    final isUp = stock.trend == 'up' || stock.changePct >= 0;
    final color = isUp ? Colors.green : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          // Ticker
          SizedBox(
            width: 52,
            child: Text(stock.ticker, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          // Company
          Expanded(
            child: Text(
              stock.company,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Price
          Text(
            '\$${stock.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          // Change badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 14, color: color),
                Text(
                  '${stock.changePct.abs().toStringAsFixed(2)}%',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Volume
          Text(stock.volume, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder)),
        ],
      ),
    );
  }
}

class _FinanceSkeleton extends StatelessWidget {
  const _FinanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Gauge placeholder
        SkeletonBox(width: double.infinity, height: 100, radius: 16),
        const SizedBox(height: 16),

        // Market status banner placeholder
        SkeletonBox(width: double.infinity, height: 44, radius: 12),
        const SizedBox(height: 20),

        // Section header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBox(width: 130, height: 14),
            SkeletonBox(width: 80, height: 12),
          ],
        ),
        const SizedBox(height: 12),

        // 2-column indices grid (2 rows × 2 cols)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: List.generate(4, (_) => SkeletonBox(height: double.infinity, radius: 14)),
        ),
        const SizedBox(height: 24),

        // Crypto section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBox(width: 80, height: 14),
            SkeletonBox(width: 100, height: 10),
          ],
        ),
        const SizedBox(height: 12),

        // 4 crypto rows
        ...List.generate(4, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SkeletonListTile(),
        )),
        const SizedBox(height: 24),

        // News section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBox(width: 100, height: 14),
            SkeletonBox(width: 60, height: 10),
          ],
        ),
        const SizedBox(height: 12),

        // 3 news rows: small image + two text lines
        ...List.generate(3, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 44, height: 44, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: double.infinity, height: 13),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 100, height: 10),
                  ],
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 100),
      ],
    );
  }
}
