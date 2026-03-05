import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/cyclops_graph.dart';
// ─── Constants ─────────────────────────────────────────────────────────────────

const _cyclopsBaseUrl = 'https://cyclops-api.daemonprotocol.com';
const _daemonLlmUrl = 'https://d-mdlwr.daemonprotocol.com/api/llm/chat';
const _cyclopsBlue = Color(0xFF00E5FF);

// ─── Main Screen ───────────────────────────────────────────────────────────────

class CyclopsScreen extends StatefulWidget {
  const CyclopsScreen({super.key});

  @override
  State<CyclopsScreen> createState() => _CyclopsScreenState();
}

class _CyclopsScreenState extends State<CyclopsScreen> {
  final _controller = TextEditingController();
  int _depth = 3;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;

  // AI analysis
  String? _aiAnalysis;
  bool _aiLoading = false;
  String? _aiError;

  // Search history
  final List<String> _history = [];

  Future<void> _analyze([String? query]) async {
    final input = query ?? _controller.text.trim();
    if (input.isEmpty) return;

    // Add to history (deduplicated)
    if (!_history.contains(input)) {
      setState(() => _history.insert(0, input));
    }
    _controller.text = input;

    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
      _aiAnalysis = null;
      _aiError = null;
      _aiLoading = false;
    });

    try {
      final response = await http.post(
        Uri.parse('$_cyclopsBaseUrl/api/v1/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'input': input, 'maxDepth': _depth}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        setState(() {
          _result = data;
          _isLoading = false;
        });
        // Auto-fetch AI analysis
        if (data != null) _fetchAiAnalysis(data);
      } else {
        final msg = (body['error'] as Map<String, dynamic>?)?['message'] as String?
            ?? 'Analysis failed (${response.statusCode})';
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAiAnalysis(Map<String, dynamic> data) async {
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });

    try {
      final riskScore = (data['riskScore'] as num?)?.toInt() ?? 0;
      final riskLevel = data['riskLevel'] as String? ?? 'UNKNOWN';
      final chain = data['chain'] as String? ?? '';
      final entity = data['entity'] as String?;
      final address = data['address'] as String? ?? '';
      final isSanctioned = (data['sanctions'] as Map<String, dynamic>?)?['isSanctioned'] == true;
      final sanctionPrograms = ((data['sanctions'] as Map<String, dynamic>?)?['programs'] as List?)?.cast<String>() ?? [];
      final labels = data['labels'] as Map<String, dynamic>?;
      final categories = (labels?['categories'] as List?)?.cast<String>() ?? [];
      final attributes = (labels?['attributes'] as List?)?.cast<String>() ?? [];
      final riskIndicators = (labels?['riskIndicators'] as List?)?.cast<String>() ?? [];
      final graph = data['graph'] as Map<String, dynamic>?;
      final nodeCount = (graph?['nodes'] as List?)?.length ?? 0;
      final edgeCount = (graph?['edges'] as List?)?.length ?? 0;

      final prompt = '''Analyze this wallet/entity for potential risks and suspicious activities:

Address: $address
Entity: ${entity ?? 'Unknown'}
Chain: $chain
Risk Score: $riskScore/100 ($riskLevel)
Sanctioned: ${isSanctioned ? 'Yes - ${sanctionPrograms.join(', ')}' : 'No'}
Categories: ${categories.join(', ').isNotEmpty ? categories.join(', ') : 'None'}
Attributes: ${attributes.join(', ').isNotEmpty ? attributes.join(', ') : 'None'}
Risk Indicators: ${riskIndicators.join(', ').isNotEmpty ? riskIndicators.join(', ') : 'None'}
Transaction Graph: $nodeCount nodes, $edgeCount edges

Provide a concise 2-3 sentence analysis of the risk profile and any red flags.''';

      // Try Daemon backend first, fallback to OpenRouter free model
      final requestBody = jsonEncode({
        'model': 'arcee-ai/trinity-large-preview:free',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a blockchain security analyst. Provide concise risk assessments based on wallet data.'
          },
          {'role': 'user', 'content': prompt},
        ],
      });

      String? analysisText;

      // Try Daemon LLM backend
      try {
        final r = await http.post(
          Uri.parse(_daemonLlmUrl),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        ).timeout(const Duration(seconds: 20));
        final rb = jsonDecode(r.body) as Map<String, dynamic>;
        analysisText = rb['choices']?[0]?['message']?['content'] as String?
            ?? rb['content'] as String?
            ?? rb['message'] as String?;
      } catch (_) {}

      // Fallback: use OpenRouter free model directly
      if (analysisText == null || analysisText.isEmpty) {
        try {
          final fallbackResponse = await http.post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'stepfun/step-3.5-flash:free',
              'messages': [
                {'role': 'system', 'content': 'You are a blockchain security analyst.'},
                {'role': 'user', 'content': prompt},
              ],
            }),
          ).timeout(const Duration(seconds: 20));
          final fb = jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
          analysisText = fb['choices']?[0]?['message']?['content'] as String?;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _aiAnalysis = analysisText ?? 'Unable to generate analysis.';
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = 'AI analysis unavailable';
        _aiLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Graph panel visibility
  bool _showGraph = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _cyclopsBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.remove_red_eye_outlined, color: _cyclopsBlue, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CYCLOPS',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _cyclopsBlue,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Wallet Tracer',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          // Graph toggle button — only shown when result exists
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _showGraph = !_showGraph),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _showGraph
                        ? _cyclopsBlue.withValues(alpha: 0.2)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showGraph ? _cyclopsBlue : AppTheme.borderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.device_hub,
                        size: 14,
                        color: _showGraph ? _cyclopsBlue : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Graph',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _showGraph ? _cyclopsBlue : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Top: Search + Info Panel (scrollable) ─────────────────
          Expanded(
            flex: _showGraph ? 0 : 1,
            child: _showGraph
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Search Panel
                      _SearchPanel(
                        controller: _controller,
                        depth: _depth,
                        isLoading: _isLoading,
                        history: _history,
                        onDepthChanged: (d) => setState(() => _depth = d),
                        onSearch: _analyze,
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(message: _error!),
                      ],

                      if (_result != null) ...[
                        const SizedBox(height: 20),
                        _InfoPanel(
                          data: _result!,
                          aiAnalysis: _aiAnalysis,
                          aiLoading: _aiLoading,
                          aiError: _aiError,
                        ),
                      ],

                      if (_isLoading) ...[
                        const SizedBox(height: 20),
                        _LoadingSkeleton(),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
          ),

          // ── Bottom: Graph view (full screen when toggled) ──────────
          if (_showGraph && _result != null)
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  // Search bar strip at top when graph is visible
                  Container(
                    color: const Color(0xFF0d1117),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161b22),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF30363d)),
                            ),
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFf0f6fc), fontFamily: 'monospace'),
                              decoration: const InputDecoration(
                                hintText: 'Enter wallet or entity...',
                                hintStyle: TextStyle(color: Color(0xFF484f58), fontSize: 12),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              onSubmitted: (_) => _analyze(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Depth selector compact
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161b22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF30363d)),
                          ),
                          child: Row(
                            children: List.generate(5, (i) {
                              final d = i + 1;
                              final selected = _depth == d;
                              return GestureDetector(
                                onTap: () => setState(() => _depth = d),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: 22,
                                  height: 22,
                                  margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                                  decoration: BoxDecoration(
                                    color: selected ? _cyclopsBlue : const Color(0xFF21262d),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: selected ? _cyclopsBlue : Colors.transparent,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$d',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? Colors.black : const Color(0xFF6b7280),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _analyze(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLoading
                                  ? const Color(0xFF21262d)
                                  : const Color(0xFF238636),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Trace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Graph canvas
                  Expanded(
                    child: CyclopsGraph(analysisData: _result!),
                  ),
                ],
              ),
            ),

          // When graph is toggled but no result yet — show search
          if (_showGraph && _result == null)
            Expanded(
              child: Container(
                color: const Color(0xFF0d1117),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.device_hub, size: 48, color: Color(0xFF3b82f6)),
                      const SizedBox(height: 12),
                      const Text('Run a trace to see the graph',
                          style: TextStyle(color: Color(0xFF8b949e), fontSize: 14)),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: _SearchPanel(
                          controller: _controller,
                          depth: _depth,
                          isLoading: _isLoading,
                          history: _history,
                          onDepthChanged: (d) => setState(() => _depth = d),
                          onSearch: _analyze,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Search Panel ─────────────────────────────────────────────────────────────

class _SearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final int depth;
  final bool isLoading;
  final List<String> history;
  final ValueChanged<int> onDepthChanged;
  final void Function([String?]) onSearch;

  const _SearchPanel({
    required this.controller,
    required this.depth,
    required this.isLoading,
    required this.history,
    required this.onDepthChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input field
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Enter wallet or entity...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPlaceholder,
                  fontFamily: null,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),

          const SizedBox(height: 12),

          // Depth selector + Trace button row
          Row(
            children: [
              // Depth row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Depth',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(5, (i) {
                      final d = i + 1;
                      final selected = depth == d;
                      return GestureDetector(
                        onTap: () => onDepthChanged(d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: selected ? _cyclopsBlue : AppTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected ? _cyclopsBlue : AppTheme.borderLight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$d',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.black : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Start Trace button
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: isLoading ? null : () => onSearch(),
                    style: FilledButton.styleFrom(
                      backgroundColor: isLoading ? AppTheme.surface : const Color(0xFF238636),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Start Trace',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            ],
          ),

          // History
          if (history.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'RECENT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textPlaceholder,
                letterSpacing: 0.8,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: history.take(6).map((item) {
                final display = item.length > 14
                    ? '${item.substring(0, 6)}...${item.substring(item.length - 4)}'
                    : item;
                return GestureDetector(
                  onTap: () => onSearch(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Text(
                      display,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Info Panel (results) ─────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? aiAnalysis;
  final bool aiLoading;
  final String? aiError;

  const _InfoPanel({
    required this.data,
    this.aiAnalysis,
    required this.aiLoading,
    this.aiError,
  });

  Color _riskColor(String level) {
    switch (level) {
      case 'NO_RISK': return const Color(0xFF3FB950);
      case 'INFORMATIONAL': return const Color(0xFF58A6FF);
      case 'LOW': return const Color(0xFFA5D6A7);
      case 'MEDIUM': return const Color(0xFFD29922);
      case 'HIGH': return const Color(0xFFDB6D28);
      case 'CRITICAL': return const Color(0xFFF85149);
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskScore = (data['riskScore'] as num?)?.toInt() ?? 0;
    final riskLevel = data['riskLevel'] as String? ?? 'UNKNOWN';
    final riskDesc = data['riskLevelDescription'] as String? ?? '';
    final chain = data['chain'] as String? ?? '';
    final entity = data['entity'] as String?;
    final address = data['address'] as String? ?? '';
    final sanctions = data['sanctions'] as Map<String, dynamic>?;
    final isSanctioned = sanctions?['isSanctioned'] == true;
    final sanctionPrograms = (sanctions?['programs'] as List?)?.cast<String>() ?? [];
    final labels = data['labels'] as Map<String, dynamic>?;
    final categories = (labels?['categories'] as List?)?.cast<String>() ?? [];
    final attributes = (labels?['attributes'] as List?)?.cast<String>() ?? [];
    final riskIndicators = (labels?['riskIndicators'] as List?)?.cast<String>() ?? [];
    final graph = data['graph'] as Map<String, dynamic>?;
    final nodeCount = (graph?['nodes'] as List?)?.length ?? 0;
    final edgeCount = (graph?['edges'] as List?)?.length ?? 0;
    final metadata = data['metadata'] as Map<String, dynamic>?;
    final sourcesQueried = (metadata?['sourcesQueried'] as List?)?.cast<String>() ?? [];
    final processingMs = metadata?['processingTimeMs'] as int? ?? 0;
    final color = _riskColor(riskLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header: chain + entity/address ─────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chain,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entity ?? address,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entity != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        address,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Clipboard.setData(ClipboardData(text: address)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Risk Score ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Risk Score',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '$riskScore',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Risk progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: riskScore / 100,
                  backgroundColor: AppTheme.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                riskLevel.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (riskDesc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  riskDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Sanctions ───────────────────────────────────────────────
        if (isSanctioned) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF3D1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF85149).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SANCTIONED',
                  style: TextStyle(
                    color: Color(0xFFF85149),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (sanctionPrograms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: sanctionPrograms.map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF85149).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(fontSize: 10, color: Color(0xFFF85149)),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Labels ──────────────────────────────────────────────────
        if (categories.isNotEmpty || attributes.isNotEmpty || riskIndicators.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Labels',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Categories', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder, fontSize: 9)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: categories.map((c) => _LabelChip(text: c, color: const Color(0xFFA78BFA))).toList(),
                  ),
                ],
                if (attributes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Attributes', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder, fontSize: 9)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: attributes.map((a) => _LabelChip(text: a, color: const Color(0xFF58A6FF))).toList(),
                  ),
                ],
                if (riskIndicators.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Risk Indicators', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder, fontSize: 9)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: riskIndicators.map((r) => _LabelChip(text: r, color: const Color(0xFFF85149))).toList(),
                  ),
                ],
              ],
            ),
          ),

        if (categories.isNotEmpty || attributes.isNotEmpty || riskIndicators.isNotEmpty)
          const SizedBox(height: 12),

        // ── Stats + Sources ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats row
              Row(
                children: [
                  _StatBox(label: 'Nodes', value: '$nodeCount'),
                  const SizedBox(width: 24),
                  _StatBox(label: 'Edges', value: '$edgeCount'),
                ],
              ),
              const SizedBox(height: 14),
              // Sources
              Text(
                'Data Sources',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: sourcesQueried.map((s) {
                  String display = s;
                  if (s == 'helius') display = 'RPC-SOL';
                  if (s == 'etherscan') display = 'RPC-ETH';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(display, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                  );
                }).toList(),
              ),
              if (processingMs > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${processingMs}ms',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── AI Analysis ─────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A1F2E),
                AppTheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cyclopsBlue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: _cyclopsBlue),
                    const SizedBox(width: 6),
                    Text(
                      'AI Analysis',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _cyclopsBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (aiLoading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerLine(width: double.infinity),
                      const SizedBox(height: 8),
                      _ShimmerLine(width: 200),
                      const SizedBox(height: 8),
                      _ShimmerLine(width: 140),
                    ],
                  ),
                )
              else if (aiError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    aiError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFF85149)),
                  ),
                )
              else if (aiAnalysis != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    aiAnalysis!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder),
        ),
      ],
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String text;
  final Color color;

  const _LabelChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _ShimmerLine extends StatefulWidget {
  final double width;
  const _ShimmerLine({required this.width});

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        width: widget.width,
        height: 12,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (_anim.value - 0.5).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.5).clamp(0.0, 1.0),
            ],
            colors: [
              AppTheme.surface,
              _cyclopsBlue.withValues(alpha: 0.25),
              AppTheme.surface,
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: _cyclopsBlue, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Analyzing wallet...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _cyclopsBlue),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ShimmerLine(width: double.infinity),
          const SizedBox(height: 8),
          _ShimmerLine(width: 240),
          const SizedBox(height: 8),
          _ShimmerLine(width: 180),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
