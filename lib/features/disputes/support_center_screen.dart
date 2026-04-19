import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/disputes/services/dispute_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  final _disputeService = DisputeService();
  final _shipmentIdController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _sending = false;

  Future<void> _sendTicket() async {
    final shipmentId = _shipmentIdController.text.trim();
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (shipmentId.isEmpty || subject.isEmpty || message.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa el envío, el asunto y el mensaje.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _disputeService.createDispute(
        shipmentId: shipmentId,
        reason: subject,
        context: message,
      );
      _shipmentIdController.clear();
      _subjectController.clear();
      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu mensaje fue enviado al Admin Web.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _shipmentIdController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF111216), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            children: [
              AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
              const SizedBox(height: 24),
              const AppPageIntro(
                title: 'Soporte técnico',
                subtitle: 'Escribe directo al equipo admin. Sin discusiones viejas ni bandejas saturadas.',
              ),
              const SizedBox(height: 16),
              AppGlassSection(
                title: 'Nuevo mensaje',
                child: Column(
                  children: [
                    TextField(
                      controller: _shipmentIdController,
                      decoration: const InputDecoration(labelText: 'ID del envío'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(labelText: 'Asunto'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Mensaje para soporte'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _sendTicket,
                        child: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Enviar al Admin Web'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
