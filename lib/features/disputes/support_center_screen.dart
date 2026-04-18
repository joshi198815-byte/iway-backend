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
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar soporte.')),
      );
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Abierta';
      case 'escalated':
        return 'Escalada';
      case 'resolved':
        return 'Resuelta';
      case 'rejected':
        return 'Cerrada';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.greenAccent;
      case 'escalated':
        return Colors.orangeAccent;
      case 'rejected':
        return AppTheme.muted;
      default:
        return AppTheme.primary;
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
                        subtitle: 'Aquí ves los casos enviados, su estado y la respuesta operativa.',
                      ),
                      const SizedBox(height: 16),
                      if (_items.isEmpty)
                        const AppGlassSection(
                          title: 'Sin incidencias',
                          child: Text(
                            'Todavía no has enviado casos a soporte.',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        )
                      else
                        ..._items.map(
                          (item) {
                            final shipment = item['shipment'];
                            final shipmentId = shipment is Map ? shipment['id']?.toString() ?? '' : '';
                            final route = shipment is Map
                                ? '${shipment['origen'] ?? ''} → ${shipment['destino'] ?? ''}'
                                : 'Pedido relacionado';
                            final status = item['status']?.toString() ?? 'open';
                            final reason = item['reason']?.toString() ?? '';
                            final resolution = item['resolution']?.toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppGlassSection(
                                title: route,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: _statusColor(status).withValues(alpha: 0.32)),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      reason,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    if (resolution != null && resolution.trim().isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Respuesta: $resolution',
                                        style: const TextStyle(color: AppTheme.muted, height: 1.4),
                                      ),
                                    ],
                                    if (shipmentId.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => Navigator.pushNamed(
                                                context,
                                                '/tracking',
                                                arguments: shipmentId,
                                              ),
                                              child: const Text('Ver pedido'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
