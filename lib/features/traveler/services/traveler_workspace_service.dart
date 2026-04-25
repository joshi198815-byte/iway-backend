import 'package:iway_app/services/api_client.dart';

bool _isMissingRouteAnnouncementEndpoint(Object error) {
  return error is ApiException &&
      error.statusCode == 404 &&
      error.message.toLowerCase().contains('cannot get');
}

class TravelerWorkspaceState {
  final bool isOnline;
  final List<String> routes;

  const TravelerWorkspaceState({
    required this.isOnline,
    required this.routes,
  });

  factory TravelerWorkspaceState.fromJson(Map<String, dynamic> json) {
    final routes = (json['routes'] as List?)
            ?.map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];

    return TravelerWorkspaceState(
      isOnline: json['isOnline'] != false,
      routes: routes,
    );
  }
}

class TravelerRouteAnnouncement {
  final String message;
  final List<String> allowedProducts;
  final List<String> regions;
  final DateTime? createdAt;
  final int recipientCount;

  const TravelerRouteAnnouncement({
    required this.message,
    required this.allowedProducts,
    required this.regions,
    required this.createdAt,
    required this.recipientCount,
  });

  factory TravelerRouteAnnouncement.fromJson(Map<String, dynamic> json) {
    return TravelerRouteAnnouncement(
      message: (json['message'] ?? '').toString(),
      allowedProducts: (json['allowedProducts'] as List?)?.map((item) => item.toString()).toList() ?? const <String>[],
      regions: (json['regions'] as List?)?.map((item) => item.toString()).toList() ?? const <String>[],
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class TravelerWorkspaceService {
  TravelerWorkspaceService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<TravelerWorkspaceState> getWorkspace() async {
    final data = await _apiClient.get('/travelers/me/workspace');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar tu modo de trabajo.');
    }
    return TravelerWorkspaceState.fromJson(data);
  }

  Future<TravelerWorkspaceState> updateWorkspace({
    bool? isOnline,
    List<String>? routes,
  }) async {
    final payload = <String, dynamic>{};
    if (isOnline != null) payload['isOnline'] = isOnline;
    if (routes != null) payload['routes'] = routes;

    final data = await _apiClient.patch('/travelers/me/workspace', payload);
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo actualizar tu modo de trabajo.');
    }
    return TravelerWorkspaceState.fromJson(data);
  }

  Future<TravelerRouteAnnouncement?> getLatestRouteAnnouncement() async {
    try {
      final data = await _apiClient.get('/travelers/me/route-announcement');
      if (data == null) return null;
      if (data is! Map<String, dynamic>) {
        throw ApiException('No se pudo cargar tu anuncio de ruta.');
      }
      return TravelerRouteAnnouncement.fromJson(data);
    } catch (error) {
      if (_isMissingRouteAnnouncementEndpoint(error)) {
        return null;
      }
      rethrow;
    }
  }

  Future<TravelerRouteAnnouncement> publishRouteAnnouncement({
    required String message,
    required List<String> allowedProducts,
    List<String> regions = const [],
  }) async {
    try {
      final data = await _apiClient.post('/travelers/me/route-announcement', {
        'message': message,
        'allowedProducts': allowedProducts,
        'regions': regions,
      });
      if (data is! Map<String, dynamic>) {
        throw ApiException('No se pudo publicar tu anuncio de ruta.');
      }
      return TravelerRouteAnnouncement.fromJson(data);
    } catch (error) {
      if (_isMissingRouteAnnouncementEndpoint(error)) {
        throw ApiException('Tu backend actual todavía no expone anuncios de ruta. Actualiza el deploy e intenta de nuevo.');
      }
      rethrow;
    }
  }
}
