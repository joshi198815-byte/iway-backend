import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/rating/models/rating_model.dart';
import 'package:iway_app/features/rating/services/rating_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';

class MyRatingsScreen extends StatefulWidget {
  const MyRatingsScreen({super.key});

  @override
  State<MyRatingsScreen> createState() => _MyRatingsScreenState();
}

class _MyRatingsScreenState extends State<MyRatingsScreen> {
  final _ratingService = RatingService();
  List<RatingModel> _ratings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final ratings = await _ratingService.getRatings(userId);
      if (!mounted) return;
      setState(() {
        _ratings = ratings;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar tus calificaciones.')),
      );
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'traveler':
        return 'Viajero';
      case 'customer':
        return 'Cliente';
      default:
        return 'Usuario';
    }
  }

  String _maskedShipmentId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '####';
    final suffix = trimmed.length <= 4 ? trimmed : trimmed.substring(trimmed.length - 4);
    return '••••$suffix';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Fecha no disponible';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year · ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF101116), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                      const SizedBox(height: 24),
                      const Text(
                        'Mis calificaciones',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Solo estrellas, comentarios y fecha clara.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: _ratings.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.star_outline_rounded,
                                title: 'Todavía no tienes calificaciones',
                                subtitle: 'Cuando completes entregas y te evalúen, aparecerán aquí.',
                              )
                            : ListView.separated(
                                itemCount: _ratings.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final rating = _ratings[index];
                                  return AppGlassSection(
                                    title: rating.fromUserName.isNotEmpty ? rating.fromUserName : _roleLabel(rating.fromUserRole),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _roleLabel(rating.fromUserRole),
                                              style: const TextStyle(color: AppTheme.muted),
                                            ),
                                            const Spacer(),
                                            ...List.generate(
                                              5,
                                              (starIndex) => Icon(
                                                starIndex < rating.estrellas ? Icons.star_rounded : Icons.star_border_rounded,
                                                size: 18,
                                                color: const Color(0xFFFFC83D),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          rating.comentario.isEmpty ? 'Sin comentario adicional.' : rating.comentario,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Envío ${_maskedShipmentId(rating.shipmentId)}',
                                          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(rating.createdAt),
                                          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
