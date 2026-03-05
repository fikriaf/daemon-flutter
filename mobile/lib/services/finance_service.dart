import 'api_service.dart';

class FinanceService {
  final ApiService _api;

  FinanceService(this._api);

  Future<FinanceData> getMarketData() async {
    final data = await _api.get('/v1/agent/finance');
    return FinanceData.fromJson(data);
  }

  Future<FinanceAnalysis> getFinanceAnalysis() async {
    final data = await _api.get('/v1/agent/finance/analysis');
    return FinanceAnalysis.fromJson(data);
  }

  Future<EarningsData> getEarnings() async {
    final data = await _api.get('/v1/agent/finance/earnings');
    return EarningsData.fromJson(data);
  }

  Future<PredictionsData> getPredictions() async {
    final data = await _api.get('/v1/agent/finance/predictions');
    return PredictionsData.fromJson(data);
  }

  Future<ScreenerData> getScreener() async {
    final data = await _api.get('/v1/agent/finance/screener');
    return ScreenerData.fromJson(data);
  }
}

class FinanceData {
  final List<Index> indices;
  final List<Crypto> crypto;
  final Sentiment sentiment;
  final List<MarketSummary> marketSummary;
  final List<Tab> tabs;
  final MarketStatus? marketStatus;
  final DateTime updatedAt;

  FinanceData({
    required this.indices,
    required this.crypto,
    required this.sentiment,
    required this.marketSummary,
    required this.tabs,
    this.marketStatus,
    required this.updatedAt,
  });

  factory FinanceData.fromJson(Map<String, dynamic> json) {
    return FinanceData(
      indices: (json['indices'] as List?)
              ?.map((e) => Index.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      crypto: (json['crypto'] as List?)
              ?.map((e) => Crypto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sentiment: json['sentiment'] != null
          ? Sentiment.fromJson(json['sentiment'] as Map<String, dynamic>)
          : Sentiment.empty(),
      marketSummary: (json['market_summary'] as List?)
              ?.map((e) => MarketSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tabs: (json['tabs'] as List?)
              ?.map((e) => Tab.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      marketStatus: json['market_status'] != null
          ? MarketStatus.fromJson(json['market_status'] as Map<String, dynamic>)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}

class MarketStatus {
  final bool isOpen;
  final String nextEvent;
  final String nextEventTime;

  MarketStatus({
    required this.isOpen,
    required this.nextEvent,
    required this.nextEventTime,
  });

  factory MarketStatus.fromJson(Map<String, dynamic> json) {
    return MarketStatus(
      isOpen: json['is_open'] == true,
      nextEvent: json['next_event'] as String? ?? 'opens',
      nextEventTime: json['next_event_time'] as String? ?? '9:30 AM ET',
    );
  }
}

class FinanceAnalysis {
  final String analysis;
  final String? modelUsed;
  final DateTime generatedAt;
  final DateTime validUntil;
  final Sentiment? sentiment;

  FinanceAnalysis({
    required this.analysis,
    this.modelUsed,
    required this.generatedAt,
    required this.validUntil,
    this.sentiment,
  });

  factory FinanceAnalysis.fromJson(Map<String, dynamic> json) {
    return FinanceAnalysis(
      analysis: json['analysis'] as String? ?? '',
      modelUsed: json['model_used'] as String?,
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : DateTime.now(),
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : DateTime.now().add(const Duration(hours: 1)),
      sentiment: json['sentiment'] != null
          ? Sentiment.fromJson(json['sentiment'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Index {
  final String symbol;
  final String name;
  final double value;
  final double change;
  final double pctChange;
  final String trend;

  Index({
    required this.symbol,
    required this.name,
    required this.value,
    required this.change,
    required this.pctChange,
    required this.trend,
  });

  factory Index.fromJson(Map<String, dynamic> json) {
    return Index(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      value: (json['value'] as num? ?? 0).toDouble(),
      change: (json['change'] as num? ?? 0).toDouble(),
      pctChange: (json['pct_change'] as num? ?? 0).toDouble(),
      trend: json['trend'] as String? ?? 'down',
    );
  }
}

class Crypto {
  final String symbol;
  final String name;
  final double price;
  final double change24h;
  final String trend;

  Crypto({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change24h,
    required this.trend,
  });

  factory Crypto.fromJson(Map<String, dynamic> json) {
    return Crypto(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num? ?? 0).toDouble(),
      change24h: (json['change_24h'] as num? ?? 0).toDouble(),
      trend: json['trend'] as String? ?? 'down',
    );
  }
}

class Sentiment {
  final String overall;
  final int fearGreedIndex;
  final String label;

  Sentiment({
    required this.overall,
    required this.fearGreedIndex,
    required this.label,
  });

  factory Sentiment.fromJson(Map<String, dynamic> json) {
    return Sentiment(
      overall: json['overall'] as String? ?? 'neutral',
      fearGreedIndex: json['fear_greed_index'] as int? ?? 50,
      label: json['label'] as String? ?? 'Neutral',
    );
  }

  factory Sentiment.empty() {
    return Sentiment(overall: 'neutral', fearGreedIndex: 50, label: 'Neutral');
  }
}

class MarketSummary {
  final String title;
  final String summary;
  final String source;
  final DateTime publishedAt;
  final String? imageUrl;
  final String? url;

  MarketSummary({
    required this.title,
    required this.summary,
    required this.source,
    required this.publishedAt,
    this.imageUrl,
    this.url,
  });

  factory MarketSummary.fromJson(Map<String, dynamic> json) {
    return MarketSummary(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      source: json['source'] as String? ?? '',
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : DateTime.now(),
      imageUrl: json['image_url'] as String?,
      url: json['url'] as String?,
    );
  }
}

class Tab {
  final String id;
  final String name;

  Tab({required this.id, required this.name});

  factory Tab.fromJson(Map<String, dynamic> json) {
    return Tab(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

// ─── Earnings ───────────────────────────────────────────────────────────────

class EarningsData {
  final List<EarningsEntry> earningsCalendar;
  final List<EarningsEntry> recentReports;
  final String? aiSummary;
  final DateTime updatedAt;

  EarningsData({required this.earningsCalendar, required this.recentReports, this.aiSummary, required this.updatedAt});

  factory EarningsData.fromJson(Map<String, dynamic> json) => EarningsData(
    earningsCalendar: (json['earnings_calendar'] as List?)?.map((e) => EarningsEntry.fromJson(e)).toList() ?? [],
    recentReports: (json['recent_reports'] as List?)?.map((e) => EarningsEntry.fromJson(e)).toList() ?? [],
    aiSummary: json['ai_summary'] as String?,
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
  );
}

class EarningsEntry {
  final String ticker;
  final String company;
  final String reportDate;
  final String reportTime;
  final double? estimateEps;
  final double? actualEps;
  final String? estimateRevenue;
  final String? actualRevenue;
  final double? surprisePct;
  final String status; // "upcoming" | "reported"

  EarningsEntry({required this.ticker, required this.company, required this.reportDate, required this.reportTime, this.estimateEps, this.actualEps, this.estimateRevenue, this.actualRevenue, this.surprisePct, required this.status});

  factory EarningsEntry.fromJson(Map<String, dynamic> json) => EarningsEntry(
    ticker: json['ticker'] ?? '',
    company: json['company'] ?? '',
    reportDate: json['report_date'] ?? '',
    reportTime: json['report_time'] ?? '',
    estimateEps: (json['estimate_eps'] as num?)?.toDouble(),
    actualEps: (json['actual_eps'] as num?)?.toDouble(),
    estimateRevenue: json['estimate_revenue'] as String?,
    actualRevenue: json['actual_revenue'] as String?,
    surprisePct: (json['surprise_pct'] as num?)?.toDouble(),
    status: json['status'] ?? 'upcoming',
  );
}

// ─── Predictions ─────────────────────────────────────────────────────────────

class PredictionsData {
  final List<StockPrediction> predictions;
  final MarketPrediction? marketPrediction;
  final DateTime updatedAt;

  PredictionsData({required this.predictions, this.marketPrediction, required this.updatedAt});

  factory PredictionsData.fromJson(Map<String, dynamic> json) => PredictionsData(
    predictions: (json['predictions'] as List?)?.map((e) => StockPrediction.fromJson(e)).toList() ?? [],
    marketPrediction: json['market_prediction'] != null ? MarketPrediction.fromJson(json['market_prediction']) : null,
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
  );
}

class StockPrediction {
  final String ticker;
  final String company;
  final double currentPrice;
  final double targetPrice;
  final double upsidePct;
  final String timeframe;
  final String analystRating;
  final int? analystCount;
  final double confidence;
  final String? aiRationale;
  final PriceTargets? priceTargets;

  StockPrediction({required this.ticker, required this.company, required this.currentPrice, required this.targetPrice, required this.upsidePct, required this.timeframe, required this.analystRating, this.analystCount, required this.confidence, this.aiRationale, this.priceTargets});

  factory StockPrediction.fromJson(Map<String, dynamic> json) => StockPrediction(
    ticker: json['ticker'] ?? '',
    company: json['company'] ?? '',
    currentPrice: (json['current_price'] as num? ?? 0).toDouble(),
    targetPrice: (json['target_price'] as num? ?? 0).toDouble(),
    upsidePct: (json['upside_pct'] as num? ?? 0).toDouble(),
    timeframe: json['timeframe'] ?? '12 months',
    analystRating: json['analyst_rating'] ?? 'Hold',
    analystCount: json['analyst_count'] as int?,
    confidence: (json['confidence'] as num? ?? 0.5).toDouble(),
    aiRationale: json['ai_rationale'] as String?,
    priceTargets: json['price_targets'] != null ? PriceTargets.fromJson(json['price_targets']) : null,
  );
}

class PriceTargets {
  final double low;
  final double median;
  final double high;

  PriceTargets({required this.low, required this.median, required this.high});

  factory PriceTargets.fromJson(Map<String, dynamic> json) => PriceTargets(
    low: (json['low'] as num? ?? 0).toDouble(),
    median: (json['median'] as num? ?? 0).toDouble(),
    high: (json['high'] as num? ?? 0).toDouble(),
  );
}

class MarketPrediction {
  final int sp500Target;
  final int sp500Current;
  final double upsidePct;
  final String timeframe;
  final String? aiOutlook;

  MarketPrediction({required this.sp500Target, required this.sp500Current, required this.upsidePct, required this.timeframe, this.aiOutlook});

  factory MarketPrediction.fromJson(Map<String, dynamic> json) => MarketPrediction(
    sp500Target: json['sp500_target'] as int? ?? 6000,
    sp500Current: json['sp500_current'] as int? ?? 5946,
    upsidePct: (json['upside_pct'] as num? ?? 0).toDouble(),
    timeframe: json['timeframe'] ?? '12 months',
    aiOutlook: json['ai_outlook'] as String?,
  );
}

// ─── Screener ────────────────────────────────────────────────────────────────

class ScreenerData {
  final List<ScreenerStock> topGainers;
  final List<ScreenerStock> topLosers;
  final List<ScreenerStock> mostActive;
  final List<SectorPerformance> sectorPerformance;
  final DateTime updatedAt;

  ScreenerData({required this.topGainers, required this.topLosers, required this.mostActive, required this.sectorPerformance, required this.updatedAt});

  factory ScreenerData.fromJson(Map<String, dynamic> json) => ScreenerData(
    topGainers: (json['top_gainers'] as List?)?.map((e) => ScreenerStock.fromJson(e)).toList() ?? [],
    topLosers: (json['top_losers'] as List?)?.map((e) => ScreenerStock.fromJson(e)).toList() ?? [],
    mostActive: (json['most_active'] as List?)?.map((e) => ScreenerStock.fromJson(e)).toList() ?? [],
    sectorPerformance: (json['sector_performance'] as List?)?.map((e) => SectorPerformance.fromJson(e)).toList() ?? [],
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
  );
}

class ScreenerStock {
  final String ticker;
  final String company;
  final double price;
  final double change;
  final double changePct;
  final String volume;
  final String? marketCap;
  final String? sector;
  final double? peRatio;
  final String trend;

  ScreenerStock({required this.ticker, required this.company, required this.price, required this.change, required this.changePct, required this.volume, this.marketCap, this.sector, this.peRatio, required this.trend});

  factory ScreenerStock.fromJson(Map<String, dynamic> json) => ScreenerStock(
    ticker: json['ticker'] ?? '',
    company: json['company'] ?? '',
    price: (json['price'] as num? ?? 0).toDouble(),
    change: (json['change'] as num? ?? 0).toDouble(),
    changePct: (json['change_pct'] as num? ?? 0).toDouble(),
    volume: json['volume'] ?? '0',
    marketCap: json['market_cap'] as String?,
    sector: json['sector'] as String?,
    peRatio: (json['pe_ratio'] as num?)?.toDouble(),
    trend: json['trend'] ?? 'up',
  );
}

class SectorPerformance {
  final String sector;
  final double changePct;
  final String trend;

  SectorPerformance({required this.sector, required this.changePct, required this.trend});

  factory SectorPerformance.fromJson(Map<String, dynamic> json) => SectorPerformance(
    sector: json['sector'] ?? '',
    changePct: (json['change_pct'] as num? ?? 0).toDouble(),
    trend: json['trend'] ?? 'up',
  );
}
