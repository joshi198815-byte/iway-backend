import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/disputes/services/dispute_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/ui/app_skeleton.dart';

class AdminDisputesScreen extends StatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  final service = DisputeService();
  final resolutionController = TextEditingController();
  bool loading = true;
  String? processingId;
  List<Map<String, dynamic>> disputes = [];

  @override
  void initState() {
    super.initState();
    loadQueue();
  }

  Future<void> loadQueue() async {
    try {
      final data = await service.getQueue();
      if (!mounted) return;
      setState(() {
        disputes = data;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> resolve(Map<String, dynamic> dispute, String status) async {
    final disputeId = dispute['id']?.toString();
    if (disputeId == null || disputeId.isEmpty) return;
    resolutionController.clear();
    final resolution = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(status == 'resolved' ? 'Resolver disputa' : status == 'escalated' ? 'Escalar disputa' : 'Cerrar disputa'),
        content: TextField(
          controller: resolutionController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Resumen operativo / decisión / siguientes pasos'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, resolutionController.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (resolution == null) return;

    setState(() => processingId = disputeId);
    try {
      await service.resolve(disputeId: disputeId, status: status, resolution: resolution);
      await loadQueue();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
              const SizedBox(height: 24),
              const AppPageIntro(
                title: 'Disputas operativas',
                subtitle: 'Centro de incidentes, escalaciones y resolución manual.',
              ),
              const SizedBox(height: 20),
              Expanded(
                child: loading
                    ? ListView(children: const [AppSkeletonBlock(height: 160), SizedBox(height: 12), AppSkeletonBlock(height: 160)])
                    : disputes.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.support_agent_outlined,
                            title: 'Sin disputas activas',
                            subtitle: 'No hay incidentes operativos abiertos por ahora.',
                          )
                        : ListView.separated(
                            itemCount: disputes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = disputes[index];
                              final shipment = item['shipment'];
                              final opener = item['opener'];
                              final disputeId = item['id']?.toString() ?? '';
                              final processing = processingId == disputeId;
                              return AppGlassSection(
                                title: 'Envío ${item['shipmentId']}',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(opener is Map<String, dynamic> ? (opener['fullName']?.toString() ?? 'Sin nombre') : 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(item['reason']?.toString() ?? 'Sin motivo', style: const TextStyle(color: AppTheme.muted)),
                                    if ((item['resolution']?.toString() ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text('Contexto: ${item['resolution']}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                    ],
                                    if (shipment is Map<String, dynamic>) ...[
                                      const SizedBox(height: 8),
                                      Text('Status shipment: ${shipment['status'] ?? 'n/a'}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                    ],
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(child: OutlinedButton(onPressed: processing ? null : () => resolve(item, 'escalated'), child: const Text('Escalar'))),
                                        const SizedBox(width: 10),
                                        Expanded(child: OutlinedButton(onPressed: processing ? null : () => resolve(item, 'rejected'), child: const Text('Cerrar'))),
                                        const SizedBox(width: 10),
                                        Expanded(child: ElevatedButton(onPressed: processing ? null : () => resolve(item, 'resolved'), child: const Text('Resolver'))),
                                      ],
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
    );
  }
}
