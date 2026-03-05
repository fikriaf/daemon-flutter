import 'api_service.dart';

class DiscoverService {
  final ApiService _api;

  DiscoverService(this._api);

  Future<DiscoverData> getArticles({String category = 'top', int page = 1, int limit = 10}) async {
    final data = await _api.get('/v1/agent/discover?category=$category&page=$page&limit=$limit');
    return DiscoverData.fromJson(data);
  }
}

class DiscoverData {
  final List<Article> articles;
  final List<Category> categories;
  final DateTime updatedAt;

  DiscoverData({
    required this.articles,
    required this.categories,
    required this.updatedAt,
  });

  factory DiscoverData.fromJson(Map<String, dynamic> json) {
    return DiscoverData(
      articles: (json['articles'] as List?)
              ?.map((e) => Article.fromJson(e))
              .toList() ??
          [],
      categories: (json['categories'] as List?)
              ?.map((e) => Category.fromJson(e))
              .toList() ??
          [],
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
    );
  }
}

class Article {
  final String id;
  final String title;
  final String summary;
  final String source;
  final String domain;
  final String url;
  final String? imageUrl;
  final DateTime publishedAt;
  final String category;

  Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.domain,
    required this.url,
    this.imageUrl,
    required this.publishedAt,
    required this.category,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      source: json['source'] ?? '',
      domain: json['domain'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['image_url'],
      publishedAt: json['published_at'] != null 
          ? DateTime.parse(json['published_at']) 
          : DateTime.now(),
      category: json['category'] ?? '',
    );
  }
}

class Category {
  final String id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}