import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/rating/services/rating_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class RatingScreen extends StatefulWidget {
  final String shipmentId;

  const RatingScreen({super.key, required this.shipmentId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final ratingService = RatingService();

  int estrellas = 5;
  bool saving = false;
  final comentarioController = TextEditingController();

  @override
  void dispose() {
    comentarioController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final comentario = comentarioController.text.trim();

    if (comentario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega un comentario para continuar.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await ratingService.addRating(
        shipmentId: widget.shipmentId,
        estrellas: estrellas,
        comentario: comentario,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la calificación.')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Califica la experiencia',
                  subtitle: 'Tu feedback ayuda a mejorar la calidad del servicio dentro de iWay.',
                ),
                const SizedBox(height: 20),
                AppGlassSection(
                  title: 'Tu calificación',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          final active = index < estrellas;
                          return IconButton(
                            onPressed: () => setState(() => estrellas = index + 1),
                            icon: Icon(
                              active ? Icons.star_rounded : Icons.star_border_rounded,
                              color: active ? const Color(0xFFFFC83D) : AppTheme.muted,
                              size: 34,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: comentarioController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Comentario',
                          hintText: 'Cuéntanos cómo fue la entrega, comunicación y puntualidad.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar calificación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
