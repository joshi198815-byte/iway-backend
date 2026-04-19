import 'package:iway_app/services/api_client.dart';

class HomeBannerItem {
  final String id;
  final String title;
  final String subtitle;
  final String accent;

  const HomeBannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  factory HomeBannerItem.fromJson(Map<String, dynamic> json) {
    return HomeBannerItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      accent: (json['accent'] ?? '#59D38C').toString(),
    );
  }
}

class HomeBannerService {
  HomeBannerService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<HomeBannerItem>> getHomeBanners() async {
    final data = await _apiClient.get('/content/home-banners');
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(HomeBannerItem.fromJson).toList();
  }
}
