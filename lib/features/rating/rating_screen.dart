import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/rating/services/rating_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';

class RatingScreen extends StatefulWidget {
  final String shipmentId;

  const RatingScreen({super.key, required this.shipmentId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final ratingService = RatingService();
  final comentarioController = TextEditingController();

  int estrellas = 5;
  bool saving = false;
  bool checkingExisting = true;

  @override
  void initState() {
    super.initState();
    _loadExistingRating();
  }

  Future<void> _loadExistingRating() async {
    try {
      final exists = await ratingService.hasSubmittedRating(widget.shipmentId);
      if (!mounted) return;
      if (exists) {
        Navigator.popUntil(context, (route) => route.settings.name == '/home' || route.isFirst);
        return;
      }
      setState(() => checkingExisting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => checkingExisting = false);
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias!')),
      );
      Navigator.popUntil(context, (route) => route.settings.name == '/home' || route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.contains('Ya existe una calificación enviada para este envío')) {
        Navigator.popUntil(context, (route) => route.settings.name == '/home' || route.isFirst);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
            colors: [AppTheme.background, Color(0xFF101116), AppTheme.background],
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
                const Text(
                  'Califica la experiencia',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu calificación se guarda y vuelves directo al inicio.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 24),
                if (checkingExisting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estrellas', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
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
                            hintText: 'Cuéntanos cómo fue la entrega y la atención.',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
