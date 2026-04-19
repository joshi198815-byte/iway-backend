import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/rating/models/rating_model.dart';
import 'package:iway_app/features/rating/services/rating_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              Color(0xFF101116),
              AppTheme.background,
            ],
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
                      const AppPageIntro(
                        title: 'Mis calificaciones',
                        subtitle: 'Mira quién te calificó, cuántas estrellas te dio y qué comentó sobre el paquete.',
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
                                    title: rating.fromUserName.isNotEmpty
                                        ? rating.fromUserName
                                        : 'Usuario ${rating.fromUserId}',
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
                                                starIndex < rating.estrellas
                                                    ? Icons.star_rounded
                                                    : Icons.star_border_rounded,
                                                size: 18,
                                                color: const Color(0xFFFFC83D),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          rating.comentario.isEmpty
                                              ? 'Sin comentario adicional.'
                                              : rating.comentario,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Envío: ${rating.shipmentId}',
                                          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                        ),
                                        if (rating.createdAt != null)
                                          Text(
                                            'Fecha: ${rating.createdAt!.toLocal()}',
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
