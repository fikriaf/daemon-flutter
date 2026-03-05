import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

class GraphNode {
  final String id;
  final String label;
  final String type; // WALLET, ENTITY, SANCTION, TOKEN
  final String? address;
  final int riskScore;
  final String? chain; // SOLANA, ETHEREUM, etc.
  final List<String> categories;
  final List<String> attributes;
  final List<String> riskIndicators;
  final bool isMain;

  // Computed layout position (set during layout pass)
  double x;
  double y;

  GraphNode({
    required this.id,
    required this.label,
    required this.type,
    this.address,
    required this.riskScore,
    this.chain,
    required this.categories,
    required this.attributes,
    required this.riskIndicators,
    this.isMain = false,
    this.x = 0,
    this.y = 0,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json, String? mainAddress) {
    final props = json['properties'] as Map<String, dynamic>? ?? {};
    final id = json['id'] as String? ?? '';
    final addr = json['address'] as String? ?? id;
    return GraphNode(
      id: id,
      label: json['label'] as String? ?? id,
      type: json['type'] as String? ?? 'WALLET',
      address: addr,
      riskScore: ((json['riskScore'] ?? props['riskScore']) as num?)?.toInt() ?? 0,
      chain: props['chain'] as String?,
      categories: (props['categories'] as List?)?.cast<String>() ?? [],
      attributes: (props['attributes'] as List?)?.cast<String>() ?? [],
      riskIndicators: (props['riskIndicators'] as List?)?.cast<String>() ?? [],
      isMain: addr == mainAddress || id == mainAddress,
    );
  }
}

class GraphEdge {
  final String source;
  final String target;
  final String type; // TRANSFER, OWNS, SANCTIONED_BY, INTERACTS
  final double weight;
  final int txCount;

  const GraphEdge({
    required this.source,
    required this.target,
    required this.type,
    required this.weight,
    required this.txCount,
  });

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    final props = json['properties'] as Map<String, dynamic>? ?? {};
    return GraphEdge(
      source: json['source'] as String? ?? '',
      target: json['target'] as String? ?? '',
      type: json['type'] as String? ?? 'TRANSFER',
      weight: ((json['weight'] ?? props['totalValue']) as num?)?.toDouble() ?? 0,
      txCount: (props['txCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Layout Engine ────────────────────────────────────────────────────────────

class _ColumnDef {
  final String id;
  final double width;
  final Color color;

  const _ColumnDef({required this.id, required this.width, required this.color});
}

const _vSpacing = 95.0;
const _nodeW = 175.0;
const _nodeH = 58.0;
const _mainNodeW = 190.0;
const _mainNodeH = 66.0;
const _colHeaderH = 44.0;

// Column color palette
const _inColors = [
  Color(0xFF052e16), // IN-5
  Color(0xFF14532d), // IN-4
  Color(0xFF15803d), // IN-3
  Color(0xFF16a34a), // IN-2
  Color(0xFF22c55e), // IN-1
];
const _outColors = [
  Color(0xFFef4444), // OUT-1
  Color(0xFFdc2626), // OUT-2
  Color(0xFFb91c1c), // OUT-3
  Color(0xFF991b1b), // OUT-4
  Color(0xFF7f1d1d), // OUT-5
];

List<_ColumnDef> _buildColumns(int maxDepth) {
  final cols = <_ColumnDef>[];
  final depth = maxDepth.clamp(1, 5);

  // IN columns (right-to-left order in list, but placed left of MAIN)
  for (int d = depth; d >= 1; d--) {
    final colorIdx = (d - 1).clamp(0, _inColors.length - 1);
    final w = d == 1 ? 380.0 : d == 2 ? 300.0 : d == 3 ? 260.0 : d == 4 ? 230.0 : 210.0;
    cols.add(_ColumnDef(id: 'IN-$d-ETH', width: w, color: _inColors[colorIdx]));
    cols.add(_ColumnDef(id: 'IN-$d-SOL', width: w, color: _inColors[colorIdx]));
  }

  // Center special columns
  cols.add(const _ColumnDef(id: 'OFAC', width: 300, color: Color(0xFFf85149)));
  cols.add(const _ColumnDef(id: 'MAIN', width: 300, color: Color(0xFF58a6ff)));
  cols.add(const _ColumnDef(id: 'Labeller', width: 300, color: Color(0xFFa78bfa)));

  // OUT columns
  for (int d = 1; d <= depth; d++) {
    final colorIdx = (d - 1).clamp(0, _outColors.length - 1);
    final w = d == 1 ? 380.0 : d == 2 ? 300.0 : d == 3 ? 260.0 : d == 4 ? 230.0 : 210.0;
    cols.add(_ColumnDef(id: 'OUT-$d-SOL', width: w, color: _outColors[colorIdx]));
    cols.add(_ColumnDef(id: 'OUT-$d-ETH', width: w, color: _outColors[colorIdx]));
  }

  return cols;
}

// BFS layout: assign x,y to every node
void layoutGraph({
  required List<GraphNode> nodes,
  required List<GraphEdge> edges,
  required String mainId,
  required int maxDepth,
  required double canvasHeight,
}) {
  // Build adjacency
  final outEdges = <String, List<GraphEdge>>{};
  final inEdges = <String, List<GraphEdge>>{};
  for (final e in edges) {
    outEdges.putIfAbsent(e.source, () => []).add(e);
    inEdges.putIfAbsent(e.target, () => []).add(e);
  }

  final nodeMap = {for (final n in nodes) n.id: n};
  final depth = maxDepth.clamp(1, 5);

  // Build column layout
  final cols = _buildColumns(depth);
  final colX = <String, double>{};
  double cx = 0;
  for (final col in cols) {
    colX[col.id] = cx + col.width / 2;
    cx += col.width;
  }

  final graphCenterY = canvasHeight / 2;

  // Assign main node
  final mainNode = nodeMap[mainId];
  if (mainNode != null) {
    mainNode.x = colX['MAIN'] ?? cx / 2;
    mainNode.y = graphCenterY;
  }

  // BFS to assign hop levels & directions
  final hopLevel = <String, int>{mainId: 0};
  final direction = <String, String>{mainId: 'main'};
  final queue = <String>[mainId];
  int qi = 0;

  while (qi < queue.length) {
    final nodeId = queue[qi++];
    final currentHop = hopLevel[nodeId]!;
    if (currentHop >= depth) continue;

    // Outflow: this node sent to others
    for (final e in (outEdges[nodeId] ?? [])) {
      if (!hopLevel.containsKey(e.target) && nodeMap.containsKey(e.target)) {
        hopLevel[e.target] = currentHop + 1;
        direction[e.target] = direction[nodeId] == 'main' ? 'out' : direction[nodeId]!;
        queue.add(e.target);
      }
    }
    // Inflow: others sent to this node
    for (final e in (inEdges[nodeId] ?? [])) {
      if (!hopLevel.containsKey(e.source) && nodeMap.containsKey(e.source)) {
        hopLevel[e.source] = currentHop + 1;
        direction[e.source] = direction[nodeId] == 'main' ? 'in' : direction[nodeId]!;
        queue.add(e.source);
      }
    }
  }

  // Place nodes by column
  // Track vertical occupancy per column
  final columnNodes = <String, List<GraphNode>>{};

  for (final node in nodes) {
    if (node.id == mainId) continue;
    final type = node.type;
    final chain = (node.chain ?? '').contains('SOL') ? 'SOL' : 'ETH';
    final hop = hopLevel[node.id] ?? 1;
    final dir = direction[node.id] ?? 'out';
    String colId;

    if (type == 'SANCTION') {
      colId = 'OFAC';
    } else if (type == 'ENTITY' && !node.isMain) {
      colId = 'Labeller';
    } else if (dir == 'in') {
      colId = 'IN-${hop.clamp(1, depth)}-$chain';
    } else {
      colId = 'OUT-${hop.clamp(1, depth)}-$chain';
    }

    columnNodes.putIfAbsent(colId, () => []).add(node);
  }

  // Assign y positions per column
  for (final entry in columnNodes.entries) {
    final colNodes = entry.value;
    final n = colNodes.length;
    final totalH = (n - 1) * _vSpacing;
    final startY = graphCenterY - totalH / 2;
    for (int i = 0; i < n; i++) {
      colNodes[i].x = colX[entry.key] ?? 0;
      colNodes[i].y = startY + i * _vSpacing;
    }
  }
}

// Total canvas width
double totalCanvasWidth(int maxDepth) {
  final cols = _buildColumns(maxDepth.clamp(1, 5));
  return cols.fold(0.0, (sum, c) => sum + c.width);
}

// ─── Colors ───────────────────────────────────────────────────────────────────

Color nodeAccentColor(String type, int riskScore) {
  if (type == 'SANCTION') return const Color(0xFFef4444);
  if (type == 'ENTITY') return const Color(0xFF8b5cf6);
  if (type == 'TOKEN') return const Color(0xFF22d3ee);
  // WALLET by risk score
  if (riskScore >= 81) return const Color(0xFFef4444);
  if (riskScore >= 56) return const Color(0xFFf97316);
  if (riskScore >= 36) return const Color(0xFFeab308);
  if (riskScore >= 16) return const Color(0xFF84cc16);
  if (riskScore >= 1) return const Color(0xFF3b82f6);
  return const Color(0xFF22c55e);
}

bool isHighRisk(GraphNode node) {
  if (node.riskScore >= 56) return true;
  const riskyCategories = {'SCAM', 'TERRORIST', 'HACKER', 'DARK MARKET', 'MIXER', 'RANSOMWARE', 'GAMBLING'};
  const riskyAttributes = {'SANCTIONED', 'SCAM', 'MIXING', 'ATTACKER', 'LAUNDERING', 'EXPLOIT', 'RUGPULL', 'BLOCKED', 'SUSPICIOUS'};
  if (node.categories.any(riskyCategories.contains)) return true;
  if (node.attributes.any(riskyAttributes.contains)) return true;
  return false;
}

Color edgeColor(String type) {
  switch (type) {
    case 'TRANSFER': return const Color(0xFF3b82f6);
    case 'SANCTIONED_BY': return const Color(0xFFf85149);
    case 'OWNS': return const Color(0xFFa78bfa);
    case 'INTERACTS': return const Color(0xFF22c55e);
    default: return const Color(0xFF30363d);
  }
}

double edgeWidth(String type, double weight) {
  if (type != 'TRANSFER') return 1.0;
  if (weight > 100000) return 2.5;
  if (weight > 10000) return 2.0;
  return 1.5;
}

String formatValue(double v) {
  if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
  if (v > 0) return '\$${v.toStringAsFixed(0)}';
  return '\$0';
}

String truncateAddr(String addr, [int chars = 6]) {
  if (addr.length <= chars * 2 + 3) return addr;
  return '${addr.substring(0, chars)}...${addr.substring(addr.length - chars)}';
}

// ─── Graph Painter ────────────────────────────────────────────────────────────

class CyclopsGraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? selectedNodeId;
  final String? hoveredNodeId;
  final int maxDepth;
  final double canvasH;

  CyclopsGraphPainter({
    required this.nodes,
    required this.edges,
    required this.maxDepth,
    required this.canvasH,
    this.selectedNodeId,
    this.hoveredNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cols = _buildColumns(maxDepth.clamp(1, 5));

    // Column guide lines hidden

    // Build node map for edge lookups
    final nodeMap = {for (final n in nodes) n.id: n};

    // Draw edges first (behind nodes)
    for (final edge in edges) {
      final src = nodeMap[edge.source];
      final tgt = nodeMap[edge.target];
      if (src == null || tgt == null) continue;
      _drawEdge(canvas, src, tgt, edge);
    }

    // Draw nodes
    for (final node in nodes) {
      _drawNode(canvas, node);
    }

    // Draw column headers (top strip)
    _drawColumnHeaders(canvas, cols, size.width);
  }

  void _drawNode(Canvas canvas, GraphNode node) {
    final w = node.isMain ? _mainNodeW : _nodeW;
    final h = node.isMain ? _mainNodeH : _nodeH;
    final left = node.x - w / 2;
    final top = node.y - h / 2;
    final rect = Rect.fromLTWH(left, top, w, h);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    final accent = nodeAccentColor(node.type, node.riskScore);
    final highRisk = isHighRisk(node);
    final isSelected = selectedNodeId == node.id;
    final isHovered = hoveredNodeId == node.id;

    // Background
    Color bg;
    if (node.isMain) {
      bg = const Color(0xFF1e3a5f);
    } else if (highRisk) {
      bg = const Color(0xFF2d1f1f);
    } else {
      bg = const Color(0xFF161b22);
    }

    // Shadow/glow
    if (node.isMain || highRisk || isSelected || isHovered) {
      final shadowColor = node.isMain
          ? const Color(0xFF3b82f6)
          : highRisk
              ? const Color(0xFFf85149)
              : accent;
      final shadowPaint = Paint()
        ..color = shadowColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(rr, shadowPaint);
    }

    // Fill
    canvas.drawRRect(rr, Paint()..color = bg);

    // Border
    Color borderColor;
    double borderWidth;
    if (node.isMain) {
      borderColor = const Color(0xFF3b82f6);
      borderWidth = 2;
    } else if (highRisk) {
      borderColor = const Color(0xFFf85149);
      borderWidth = 2;
    } else if (isHovered) {
      borderColor = const Color(0xFF58a6ff);
      borderWidth = 1;
    } else if (isSelected) {
      borderColor = accent;
      borderWidth = 1;
    } else {
      borderColor = const Color(0xFF30363d);
      borderWidth = 1;
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke,
    );

    // Left accent bar
    final accentRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(left, top + 5, 3, h - 10),
      topLeft: const Radius.circular(3),
      bottomLeft: const Radius.circular(3),
    );
    canvas.drawRRect(accentRect, Paint()..color = accent);

    // ── Text content ───────────────────────────────────────────────
    final textLeft = left + 10;

    // Node type label (top-left, tiny gray)
    _drawText(canvas, node.type, textLeft, top + 7, 7.5,
        const Color(0xFF6b7280), bold: false);

    // Risk score (top-right)
    _drawText(canvas, '${node.riskScore}', left + w - 8, top + 7, 9,
        accent, bold: true, align: TextAlign.right);

    // Primary label (center)
    final isAddr = node.label.startsWith('0x') || node.label.length > 20;
    final displayLabel = isAddr ? truncateAddr(node.label) : node.label;
    final labelY = node.isMain ? top + h / 2 - 6 : top + h / 2 - 5;
    _drawText(canvas, displayLabel, textLeft, labelY,
        node.isMain ? 10.5 : 9.5,
        node.isMain ? Colors.white : const Color(0xFFf0f6fc),
        bold: true,
        maxWidth: w - 20,
        fontFamily: isAddr ? 'monospace' : null);

    // Secondary address (if has entity name)
    if (node.label != node.id && node.address != null && node.address!.isNotEmpty && !isAddr) {
      _drawText(canvas, truncateAddr(node.address!), textLeft, labelY + 13,
          7.5, const Color(0xFF6b7280), fontFamily: 'monospace', maxWidth: w - 20);
    }

    // Chain label (bottom-left)
    if (node.chain != null) {
      final chainShort = node.chain!.length > 3 ? node.chain!.substring(0, 3) : node.chain!;
      _drawText(canvas, chainShort, textLeft, top + h - 13, 7,
          const Color(0xFF6b7280));
    }

    // High-risk badge (red circle with !)
    if (highRisk && !node.isMain) {
      final badgeCenter = Offset(left + w - 6, top + 6);
      canvas.drawCircle(badgeCenter, 6, Paint()..color = const Color(0xFFef4444));
      _drawText(canvas, '!', badgeCenter.dx - 2, badgeCenter.dy - 5, 8,
          Colors.white, bold: true);
    }
  }

  void _drawEdge(Canvas canvas, GraphNode src, GraphNode tgt, GraphEdge edge) {
    final color = edgeColor(edge.type);
    final width = edgeWidth(edge.type, edge.weight);

    // Determine exit/entry sides
    final goingRight = tgt.x > src.x;
    final srcW = src.isMain ? _mainNodeW : _nodeW;
    final tgtW = tgt.isMain ? _mainNodeW : _nodeW;

    final startX = goingRight ? src.x + srcW / 2 : src.x - srcW / 2;
    final startY = src.y;
    final endX = goingRight ? tgt.x - tgtW / 2 : tgt.x + tgtW / 2;
    final endY = tgt.y;

    // Bezier S-curve with 20px stubs
    const stub = 20.0;
    final cp1X = goingRight ? startX + stub : startX - stub;
    final cp2X = goingRight ? endX - stub : endX + stub;

    final path = Path()
      ..moveTo(startX, startY)
      ..cubicTo(
        cp1X,
        startY,
        cp2X,
        endY,
        endX,
        endY,
      );

    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    // Arrowhead
    _drawArrow(canvas, Offset(endX, endY), goingRight, color, 6);

    // Edge value label for TRANSFER edges
    if (edge.type == 'TRANSFER' && edge.weight > 0) {
      final midX = (startX + endX) / 2;
      final midY = (startY + endY) / 2 - 10;
      final label = txCount(edge);

      // Background pill
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 7.5, color: Color(0xFF3fb950)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bgRect = Rect.fromCenter(
        center: Offset(midX, midY + tp.height / 2),
        width: tp.width + 8,
        height: tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF0d1117),
      );
      tp.paint(canvas, Offset(midX - tp.width / 2, midY));
    }
  }

  String txCount(GraphEdge edge) {
    final v = formatValue(edge.weight);
    return edge.txCount > 0 ? '$v (${edge.txCount})' : v;
  }

  void _drawArrow(Canvas canvas, Offset tip, bool pointRight, Color color, double size) {
    final dir = pointRight ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - dir * size, tip.dy - size * 0.6)
      ..lineTo(tip.dx - dir * size, tip.dy + size * 0.6)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));
  }

  void _drawColumnHeaders(Canvas canvas, List<_ColumnDef> cols, double totalW) {
    // Hidden — column labels removed for cleaner look
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    Color color, {
    bool bold = false,
    TextAlign align = TextAlign.left,
    double? maxWidth,
    String? fontFamily,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth ?? double.infinity);

    double dx = x;
    if (align == TextAlign.right) dx = x - tp.width;

    tp.paint(canvas, Offset(dx, y));
  }

  @override
  bool shouldRepaint(CyclopsGraphPainter old) =>
      old.nodes != nodes ||
      old.edges != edges ||
      old.selectedNodeId != selectedNodeId ||
      old.hoveredNodeId != hoveredNodeId;
}

// ─── Hit-testing ──────────────────────────────────────────────────────────────

GraphNode? hitTest(List<GraphNode> nodes, Offset localPos) {
  for (final node in nodes) {
    final w = node.isMain ? _mainNodeW : _nodeW;
    final h = node.isMain ? _mainNodeH : _nodeH;
    final rect = Rect.fromCenter(center: Offset(node.x, node.y), width: w, height: h);
    if (rect.contains(localPos)) return node;
  }
  return null;
}

// ─── Main Widget ─────────────────────────────────────────────────────────────

class CyclopsGraph extends StatefulWidget {
  final Map<String, dynamic> analysisData;

  const CyclopsGraph({super.key, required this.analysisData});

  @override
  State<CyclopsGraph> createState() => _CyclopsGraphState();
}

class _CyclopsGraphState extends State<CyclopsGraph> {
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  String? _selectedNodeId;
  String? _hoveredNodeId;
  int _maxDepth = 3;
  double _canvasH = 600;

  final _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _parseAndLayout();
  }

  @override
  void didUpdateWidget(CyclopsGraph old) {
    super.didUpdateWidget(old);
    if (old.analysisData != widget.analysisData) {
      _parseAndLayout();
    }
  }

  void _parseAndLayout() {
    final data = widget.analysisData;
    final mainAddress = data['address'] as String? ?? '';
    final graph = data['graph'] as Map<String, dynamic>? ?? {};
    final nodeList = (graph['nodes'] as List?) ?? [];
    final edgeList = (graph['edges'] as List?) ?? [];

    final nodes = nodeList
        .map((n) => GraphNode.fromJson(n as Map<String, dynamic>, mainAddress))
        .toList();
    final edges = edgeList
        .map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
        .toList();

    // Determine max depth from edge count heuristic
    _maxDepth = 3;

    final mainId = nodes.firstWhere(
      (n) => n.address == mainAddress || n.id == mainAddress,
      orElse: () => nodes.isNotEmpty ? nodes.first : GraphNode(
        id: mainAddress, label: mainAddress, type: 'WALLET',
        riskScore: 0, categories: [], attributes: [], riskIndicators: [], isMain: true,
      ),
    ).id;

    // Mark main
    for (final n in nodes) {
      if (n.id == mainId) {
        // Can't set field directly — rebuild
      }
    }

    layoutGraph(
      nodes: nodes,
      edges: edges,
      mainId: mainId,
      maxDepth: _maxDepth,
      canvasHeight: _canvasH,
    );

    setState(() {
      _nodes = nodes;
      _edges = edges;
    });

    // Auto fit after layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToView());
  }

  void _fitToView() {
    if (_nodes.isEmpty) return;
    // Calculate bounds
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final n in _nodes) {
      minX = math.min(minX, n.x - _mainNodeW / 2);
      maxX = math.max(maxX, n.x + _mainNodeW / 2);
      minY = math.min(minY, n.y - _mainNodeH / 2);
      maxY = math.max(maxY, n.y + _mainNodeH / 2);
    }

    final context = this.context;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final viewW = box.size.width;
    final viewH = box.size.height;
    final contentW = maxX - minX + 120;
    final contentH = maxY - minY + 120;

    final scaleX = viewW / contentW;
    final scaleY = viewH / contentH;
    final scale = math.min(scaleX, scaleY).clamp(0.1, 1.2);

    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;

    final matrix = Matrix4.translationValues(viewW / 2 - cx * scale, viewH / 2 - cy * scale, 0)
      ..scaleByDouble(scale, scale, scale, 1.0);

    _transformController.value = matrix;
  }

  GraphNode? _selectedNode;

  // ── Tap detection via Listener ────────────────────────────────────────────
  // InteractiveViewer intercepts gestures for pan/zoom. We detect taps
  // ourselves using a Listener outside it: if pointer-up is within 12px and
  // 250ms of pointer-down, it's a tap.
  Offset? _pointerDownPos;
  int? _pointerDownMs;

  void _onPointerDown(PointerDownEvent e) {
    _pointerDownPos = e.localPosition;
    _pointerDownMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_pointerDownPos == null || _pointerDownMs == null) return;
    final dt = DateTime.now().millisecondsSinceEpoch - _pointerDownMs!;
    final delta = (e.localPosition - _pointerDownPos!).distance;
    _pointerDownPos = null;
    _pointerDownMs = null;

    // Only treat as tap if fast (<250ms) and barely moved (<12px)
    if (dt > 250 || delta > 12) return;

    _handleTap(e.localPosition);
  }

  void _handleTap(Offset screenPos) {
    // Transform from screen space → canvas space
    final matrix = _transformController.value;
    final inv = Matrix4.inverted(matrix);
    final canvas = MatrixUtils.transformPoint(inv, screenPos);
    // Subtract header offset (header is drawn at top of canvas)
    final graphPos = Offset(canvas.dx, canvas.dy - _colHeaderH);

    final hit = hitTest(_nodes, graphPos);
    setState(() {
      if (hit != null) {
        if (hit.id == _selectedNodeId) {
          // Tap same node → deselect
          _selectedNodeId = null;
          _selectedNode = null;
        } else {
          _selectedNodeId = hit.id;
          _selectedNode = hit;
        }
      } else {
        // Tap background → deselect
        _selectedNodeId = null;
        _selectedNode = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canvasW = totalCanvasWidth(_maxDepth);

    return LayoutBuilder(builder: (context, constraints) {
      _canvasH = math.max(constraints.maxHeight - _colHeaderH, 400);

      return Stack(
        children: [
          // ── Graph canvas (pan + zoom via InteractiveViewer) ────────
          // Listener lives OUTSIDE InteractiveViewer so it sees raw
          // pointer events before InteractiveViewer claims them.
          Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.05,
              maxScale: 3.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              // Let InteractiveViewer handle its own pan cursor
              child: SizedBox(
                width: canvasW,
                height: _canvasH + _colHeaderH,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFF0d1117)),
                    CustomPaint(
                      size: Size(canvasW, _canvasH + _colHeaderH),
                      painter: _CombinedPainter(
                        nodes: _nodes,
                        edges: _edges,
                        maxDepth: _maxDepth,
                        canvasH: _canvasH,
                        selectedNodeId: _selectedNodeId,
                        hoveredNodeId: _hoveredNodeId,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Zoom controls ─────────────────────────────────────────
          Positioned(
            right: 12,
            top: 60,
            child: Column(
              children: [
                _ZoomBtn(icon: Icons.fit_screen, onTap: _fitToView),
                const SizedBox(height: 4),
                _ZoomBtn(icon: Icons.add, onTap: () {
                  final m = _transformController.value.clone()..scaleByDouble(1.3, 1.3, 1.3, 1.0);
                  _transformController.value = m;
                }),
                const SizedBox(height: 4),
                _ZoomBtn(icon: Icons.remove, onTap: () {
                  final m = _transformController.value.clone()..scaleByDouble(0.75, 0.75, 0.75, 1.0);
                  _transformController.value = m;
                }),
              ],
            ),
          ),

          // ── Legend ────────────────────────────────────────────────
          Positioned(
            left: 12,
            bottom: 12,
            child: _Legend(),
          ),

          // ── Stats overlay ─────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF161b22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363d)),
              ),
              child: Text(
                '${_nodes.length} nodes · ${_edges.length} edges',
                style: const TextStyle(fontSize: 10, color: Color(0xFF8b949e)),
              ),
            ),
          ),

          // ── Selected node popup ───────────────────────────────────
          if (_selectedNode != null)
            Positioned(
              right: 12,
              bottom: 50,
              child: _NodePopup(
                node: _selectedNode!,
                onClose: () => setState(() {
                  _selectedNodeId = null;
                  _selectedNode = null;
                }),
              ),
            ),

          // ── Empty state ───────────────────────────────────────────
          if (_nodes.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.device_hub, size: 48, color: Color(0xFF3b82f6)),
                  const SizedBox(height: 12),
                  const Text(
                    'No graph data',
                    style: TextStyle(color: Color(0xFF8b949e), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Run a trace to see wallet connections',
                    style: TextStyle(color: Color(0xFF484f58), fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }
}

// ─── Combined Painter (header + graph) ───────────────────────────────────────

class _CombinedPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final int maxDepth;
  final double canvasH;
  final String? selectedNodeId;
  final String? hoveredNodeId;

  _CombinedPainter({
    required this.nodes,
    required this.edges,
    required this.maxDepth,
    required this.canvasH,
    this.selectedNodeId,
    this.hoveredNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw graph content translated down by header height
    canvas.save();
    canvas.translate(0, _colHeaderH);

    CyclopsGraphPainter(
      nodes: nodes,
      edges: edges,
      maxDepth: maxDepth,
      canvasH: canvasH,
      selectedNodeId: selectedNodeId,
      hoveredNodeId: hoveredNodeId,
    ).paint(canvas, Size(size.width, canvasH));

    canvas.restore();

    // Draw header on top
    CyclopsGraphPainter(
      nodes: nodes,
      edges: edges,
      maxDepth: maxDepth,
      canvasH: canvasH,
    )._drawColumnHeaders(canvas, _buildColumns(maxDepth.clamp(1, 5)), size.width);
  }

  @override
  bool shouldRepaint(_CombinedPainter old) =>
      old.nodes != nodes ||
      old.edges != edges ||
      old.selectedNodeId != selectedNodeId ||
      old.hoveredNodeId != hoveredNodeId;
}

// ─── Small Widgets ────────────────────────────────────────────────────────────

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF21262d),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF30363d)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF8b949e)),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (color: Color(0xFF22c55e), label: 'Clean'),
      (color: Color(0xFF3b82f6), label: 'Low Risk'),
      (color: Color(0xFFeab308), label: 'Medium'),
      (color: Color(0xFFf97316), label: 'High'),
      (color: Color(0xFFef4444), label: 'Critical'),
      (color: Color(0xFF8b5cf6), label: 'Entity'),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text(item.label, style: const TextStyle(fontSize: 9, color: Color(0xFF8b949e))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _NodePopup extends StatefulWidget {
  final GraphNode node;
  final VoidCallback onClose;

  const _NodePopup({required this.node, required this.onClose});

  @override
  State<_NodePopup> createState() => _NodePopupState();
}

class _NodePopupState extends State<_NodePopup> {
  bool _copied = false;

  void _copyAddress() {
    final addr = widget.node.address ?? widget.node.id;
    Clipboard.setData(ClipboardData(text: addr));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final accent = nodeAccentColor(node.type, node.riskScore);
    final highRisk = isHighRisk(node);
    final addr = node.address ?? node.id;
    final displayLabel = (node.label.startsWith('0x') || node.label.length > 20)
        ? truncateAddr(node.label)
        : node.label;

    return Container(
      width: 260,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highRisk ? const Color(0xFFf85149) : const Color(0xFF30363d),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0d1117),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: const Color(0xFF30363d))),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFf0f6fc),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262d),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.close, size: 12, color: Color(0xFF8b949e)),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Address (full, copyable)
                  GestureDetector(
                    onTap: _copyAddress,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0d1117),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF30363d)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              addr,
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontFamily: 'monospace',
                                color: Color(0xFF8b949e),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _copied ? Icons.check : Icons.copy,
                            size: 11,
                            color: _copied
                                ? const Color(0xFF22c55e)
                                : const Color(0xFF484f58),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Type · Chain · Risk score row
                  Row(
                    children: [
                      _Tag(text: node.type, color: accent),
                      const SizedBox(width: 4),
                      if (node.chain != null)
                        _Tag(
                          text: node.chain!.length > 3
                              ? node.chain!.substring(0, 3)
                              : node.chain!,
                          color: const Color(0xFF58a6ff),
                        ),
                      const Spacer(),
                      if (highRisk)
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFef4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('!',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                          ),
                        ),
                      _Tag(
                        text: 'Risk ${node.riskScore}',
                        color: accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Risk bar
                  _RiskBar(score: node.riskScore, color: accent),
                  const SizedBox(height: 10),

                  // Categories
                  if (node.categories.isNotEmpty) ...[
                    _sectionLabel('Categories'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: node.categories
                          .map((c) => _Tag(text: c, color: const Color(0xFF8b5cf6)))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Attributes
                  if (node.attributes.isNotEmpty) ...[
                    _sectionLabel('Attributes'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: node.attributes
                          .map((a) => _Tag(text: a, color: const Color(0xFF3b82f6)))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Risk indicators
                  if (node.riskIndicators.isNotEmpty) ...[
                    _sectionLabel('Risk Indicators'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: node.riskIndicators
                          .map((r) => _Tag(text: r, color: const Color(0xFFef4444)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBar extends StatelessWidget {
  final int score;
  final Color color;

  const _RiskBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Risk Score',
                style: TextStyle(fontSize: 8.5, color: Color(0xFF6b7280))),
            Text('$score / 100',
                style: TextStyle(
                    fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: const Color(0xFF21262d),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

Widget _sectionLabel(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 8.5,
        color: Color(0xFF6b7280),
        fontWeight: FontWeight.w500,
      ),
    );

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
