import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/admin/services/admin_antifraud_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/ui/app_skeleton.dart';

class AdminAntiFraudScreen extends StatefulWidget {
  const AdminAntiFraudScreen({super.key});

  @override
  State<AdminAntiFraudScreen> createState() => _AdminAntiFraudScreenState();
}

class _AdminAntiFraudScreenState extends State<AdminAntiFraudScreen> {
  final service = AdminAntiFraudService();

  bool loading = true;
  String? processingUserId;
  List<Map<String, dynamic>> queue = [];

  @override
  void initState() {
    super.initState();
    loadQueue();
  }

  Future<void> loadQueue() async {
    try {
      final data = await service.getReviewQueue();
      if (!mounted) return;
      setState(() {
        queue = data;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar la cola antifraude.')),
      );
    }
  }

  Future<void> recompute(String userId) async {
    setState(() => processingUserId = userId);
    try {
      await service.recompute(userId);
      await loadQueue();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => processingUserId = null);
    }
  }

  Future<void> flagUser(String userId) async {
    final reasonController = TextEditingController();
    String severity = 'medium';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Crear flag manual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: 'Severidad'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) => setModalState(() => severity = value ?? 'medium'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Motivo / evidencia'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear flag')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await service.createFlag(
      userId: userId,
      flagType: 'manual_operational_review',
      severity: severity,
      details: {'reason': reasonController.text.trim()},
    );
    await loadQueue();
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'high':
        return const Color(0xFFFF7A7A);
      case 'medium':
        return const Color(0xFFFFD27A);
      default:
        return const Color(0xFF59D38C);
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
                title: 'Cola antifraude',
                subtitle: 'Riesgo por duplicados, velocidad, devices y patrones de chat.',
              ),
              const SizedBox(height: 20),
              Expanded(
                child: loading
                    ? ListView(
                        children: const [
                          AppSkeletonBlock(height: 180),
                          SizedBox(height: 12),
                          AppSkeletonBlock(height: 180),
                        ],
                      )
                    : queue.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.shield_outlined,
                            title: 'Sin casos activos',
                            subtitle: 'No hay usuarios con riesgo medio o alto en la cola actual.',
                          )
                        : RefreshIndicator(
                            onRefresh: loadQueue,
                            child: ListView.separated(
                              itemCount: queue.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = queue[index];
                                final summary = item['summary'] as Map<String, dynamic>? ?? {};
                                final signals = summary['signals'] is List ? summary['signals'] as List : const [];
                                final userId = item['userId']?.toString() ?? '';
                                final processing = processingUserId == userId;
                                final riskLevel = summary['recommendedRiskLevel']?.toString() ?? 'low';
                                final riskScore = (summary['riskScore'] as num?)?.toInt() ?? 100;

                                return AppGlassSection(
                                  title: item['fullName']?.toString() ?? 'Traveler',
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['email']?.toString() ?? 'Sin correo', style: const TextStyle(color: AppTheme.muted)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: _MetricTile(label: 'Risk score', value: '$riskScore / 100', color: _riskColor(riskLevel))),
                                          const SizedBox(width: 12),
                                          Expanded(child: _MetricTile(label: 'Flags', value: '${summary['total'] ?? 0}', color: const Color(0xFF8AB4FF))),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text('Nivel sugerido: ${summary['recommendedRiskLevel']}', style: const TextStyle(color: AppTheme.muted)),
                                      Text('Acción: ${summary['recommendedAction']}', style: const TextStyle(color: AppTheme.muted)),
                                      if (signals.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        ...signals.take(3).map((signal) => Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: Text('• ${signal['key']} (${signal['severity']})', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                                            )),
                                      ],
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: processing ? null : () => flagUser(userId),
                                              child: const Text('Flag manual'),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: processing ? null : () => recompute(userId),
                                              child: processing
                                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                                  : const Text('Recalcular'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
        ],
      ),
    );
  }
}
