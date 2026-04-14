import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/admin/services/admin_transfer_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_info_chip.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/ui/app_skeleton.dart';

class AdminTransfersScreen extends StatefulWidget {
  const AdminTransfersScreen({super.key});

  @override
  State<AdminTransfersScreen> createState() => _AdminTransfersScreenState();
}

class _AdminTransfersScreenState extends State<AdminTransfersScreen> {
  final service = AdminTransferService();
  final reasonController = TextEditingController();

  bool loading = true;
  String? processingId;
  List<Map<String, dynamic>> transfers = [];

  @override
  void initState() {
    super.initState();
    loadQueue();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> loadQueue() async {
    try {
      final data = await service.getReviewQueue();
      if (!mounted) return;
      setState(() {
        transfers = data;
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
        const SnackBar(content: Text('No se pudo cargar la cola de transferencias.')),
      );
    }
  }

  Future<void> reviewTransfer(Map<String, dynamic> transfer, String status) async {
    final transferId = transfer['id']?.toString();
    if (transferId == null || transferId.isEmpty) return;

    String? reason;
    if (status == 'rejected') {
      reasonController.clear();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Motivo del rechazo'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej. referencia ilegible, monto no coincide, soporte incompleto',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reasonController.text.trim()),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );

      if (reason == null) return;
    }

    setState(() => processingId = transferId);
    try {
      await service.reviewTransfer(transferId: transferId, status: status, reason: reason);
      await loadQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'approved' ? 'Transferencia aprobada.' : 'Transferencia rechazada.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo revisar la transferencia.')),
      );
    } finally {
      if (mounted) setState(() => processingId = null);
    }
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _cutoffLabel(Map<String, dynamic>? settlement) {
    if (settlement == null) return 'Sin corte';
    final weekEnd = settlement['weekEnd']?.toString();
    if (weekEnd == null || weekEnd.length < 10) return 'Corte semanal';
    return 'Corte ${weekEnd.substring(0, 10)}';
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Transferencias pendientes',
                  subtitle: 'Bandeja operativa para conciliar pagos, deuda y cortes semanales.',
                ),
                const SizedBox(height: 20),
                if (!loading && transfers.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppInfoChip(icon: Icons.pending_actions_outlined, label: '${transfers.length} pendientes'),
                      AppInfoChip(icon: Icons.account_balance_wallet_outlined, label: 'Conciliación manual'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: loading
                      ? ListView(
                          children: const [
                            AppSkeletonBlock(height: 140),
                            SizedBox(height: 12),
                            AppSkeletonBlock(height: 140),
                          ],
                        )
                      : transfers.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.check_circle_outline,
                              title: 'Todo al día',
                              subtitle: 'No hay transferencias pendientes de revisión.',
                            )
                          : RefreshIndicator(
                              onRefresh: loadQueue,
                              child: ListView.separated(
                                itemCount: transfers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = transfers[index];
                                  final traveler = item['traveler'];
                                  final settlement = item['weeklySettlement'];
                                  final transferId = item['id']?.toString() ?? '';
                                  final isProcessing = processingId == transferId;
                                  final payoutPolicy = item['payoutPolicy'];

                                  return AppGlassSection(
                                    title: traveler is Map<String, dynamic>
                                        ? (traveler['fullName']?.toString() ?? 'Traveler')
                                        : 'Traveler',
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          traveler is Map<String, dynamic>
                                              ? (traveler['email']?.toString() ?? 'Sin correo')
                                              : 'Sin correo',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _MetricTile(
                                                label: 'Monto',
                                                value: _money(item['transferredAmount']),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _MetricTile(
                                                label: 'Pendiente corte',
                                                value: settlement is Map<String, dynamic>
                                                    ? _money(settlement['totalPending'])
                                                    : 'Sin corte',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Referencia: ${item['bankReference']?.toString().isNotEmpty == true ? item['bankReference'] : 'Sin referencia'}',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            AppInfoChip(
                                              icon: Icons.calendar_month_outlined,
                                              label: _cutoffLabel(settlement is Map<String, dynamic> ? settlement : null),
                                            ),
                                            AppInfoChip(
                                              icon: item['proofUrl']?.toString().isNotEmpty == true
                                                  ? Icons.attachment_outlined
                                                  : Icons.info_outline,
                                              label: item['proofUrl']?.toString().isNotEmpty == true
                                                  ? 'Con soporte'
                                                  : 'Sin soporte',
                                            ),
                                            if (payoutPolicy is Map<String, dynamic>)
                                              AppInfoChip(
                                                icon: Icons.lock_clock_outlined,
                                                label: 'Policy: ${payoutPolicy['policy'] ?? 'manual_review'}',
                                              ),
                                          ],
                                        ),
                                        if (payoutPolicy is Map<String, dynamic>) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            'Trust ${(payoutPolicy['trustScore'] ?? 0)} • KYC ${payoutPolicy['kycTier'] ?? 'basic'} • Delay ${(payoutPolicy['payoutDelayHours'] ?? 0)}h',
                                            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: isProcessing ? null : () => reviewTransfer(item, 'rejected'),
                                                child: const Text('Rechazar'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: isProcessing ? null : () => reviewTransfer(item, 'approved'),
                                                child: isProcessing
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : const Text('Aprobar'),
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
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }
}
