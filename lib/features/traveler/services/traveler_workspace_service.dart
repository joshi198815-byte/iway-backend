import 'package:iway_app/services/api_client.dart';

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
}
