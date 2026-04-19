import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/disputes/services/dispute_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> with WidgetsBindingObserver {
  final _disputeService = DisputeService();
  final _realtime = RealtimeService.instance;
  final _shipmentIdController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _sending = false;
  StreamSubscription<dynamic>? _notificationSubscription;
  StreamSubscription<dynamic>? _shipmentStatusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _bindRealtime();
  }

  Future<void> _bindRealtime() async {
    await _realtime.ensureConnected();
    _notificationSubscription = _realtime.notificationUpdated.listen((_) => _load());
    _shipmentStatusSubscription = _realtime.shipmentStatusChanged.listen((_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await _disputeService.listMine();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cargar soporte.')));
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Abierto';
      case 'escalated':
        return 'Escalado';
      case 'resolved':
        return 'Resuelto';
      case 'rejected':
        return 'Cerrado';
      default:
        return status;
    }
  }

  String _ticketLabel(Map<String, dynamic> item, int index) {
    final rawId = item['id']?.toString() ?? '${index + 1}';
    final suffix = rawId.length <= 4 ? rawId.toUpperCase() : rawId.substring(0, 4).toUpperCase();
    return 'TK-$suffix';
  }

  Future<void> _sendTicket() async {
    final shipmentId = _shipmentIdController.text.trim();
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (shipmentId.isEmpty || subject.isEmpty || message.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa envío, asunto y mensaje.')));
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
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensaje enviado al equipo de soporte.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shipmentIdController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _notificationSubscription?.cancel();
    _shipmentStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
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
            colors: [AppTheme.background, Color(0xFF111216), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                    children: [
                      AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                      const SizedBox(height: 24),
                      const AppPageIntro(
                        title: 'Soporte e incidencias',
                        subtitle: 'Formulario directo al equipo admin y seguimiento de tus casos.',
                      ),
                      const SizedBox(height: 16),
                      AppGlassSection(
                        title: 'Nuevo mensaje',
                        child: Column(
                          children: [
                            TextField(controller: _shipmentIdController, decoration: const InputDecoration(labelText: 'ID del envío')),
                            const SizedBox(height: 12),
                            TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Asunto')),
                            const SizedBox(height: 12),
                            TextField(controller: _messageController, maxLines: 4, decoration: const InputDecoration(labelText: 'Mensaje para soporte')),
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
                      const SizedBox(height: 16),
                      if (_items.isEmpty)
                        const AppGlassSection(
                          title: 'Sin tickets',
                          child: Text('Todavía no has enviado casos a soporte.', style: TextStyle(color: AppTheme.muted)),
                        )
                      else
                        ..._items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final shipment = item['shipment'];
                          final shipmentId = shipment is Map ? shipment['id']?.toString() ?? '' : '';
                          final route = shipment is Map ? '${shipment['origen'] ?? ''} → ${shipment['destino'] ?? ''}' : 'Pedido relacionado';
                          final status = item['status']?.toString() ?? 'open';
                          final reason = item['reason']?.toString() ?? '';
                          final resolution = item['resolution']?.toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppGlassSection(
                              title: '${_ticketLabel(item, index)} • $route',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_statusLabel(status), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Text(reason, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  if ((item['context']?.toString() ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(item['context'].toString(), style: const TextStyle(color: AppTheme.muted, height: 1.35)),
                                  ],
                                  if (resolution != null && resolution.trim().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text('Respuesta: $resolution', style: const TextStyle(color: AppTheme.muted, height: 1.4)),
                                  ],
                                  if (shipmentId.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    OutlinedButton(
                                      onPressed: () => Navigator.pushNamed(context, '/tracking', arguments: shipmentId),
                                      child: const Text('Abrir envío'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
