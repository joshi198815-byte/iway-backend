import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/admin/services/admin_traveler_review_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_info_chip.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/ui/app_skeleton.dart';

class AdminTravelersReviewScreen extends StatefulWidget {
  const AdminTravelersReviewScreen({super.key});

  @override
  State<AdminTravelersReviewScreen> createState() => _AdminTravelersReviewScreenState();
}

class _AdminTravelersReviewScreenState extends State<AdminTravelersReviewScreen> {
  final service = AdminTravelerReviewService();
  final reasonController = TextEditingController();

  bool loading = true;
  String? processingUserId;
  List<Map<String, dynamic>> queue = [];

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
        const SnackBar(content: Text('No se pudo cargar la cola de viajeros.')),
      );
    }
  }

  Future<void> runKycAnalysis(Map<String, dynamic> item) async {
    final userId = item['userId']?.toString();
    if (userId == null || userId.isEmpty) return;

    setState(() => processingUserId = userId);
    try {
      await service.runKycAnalysis(userId);
      await loadQueue();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => processingUserId = null);
    }
  }

  Future<void> updateHold(Map<String, dynamic> item, bool enabled) async {
    final userId = item['userId']?.toString();
    if (userId == null || userId.isEmpty) return;

    reasonController.clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(enabled ? 'Motivo del hold payout' : 'Liberar hold payout'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(hintText: enabled ? 'Explica el motivo del hold' : 'Motivo de liberación (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: Text(enabled ? 'Activar hold' : 'Liberar'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    setState(() => processingUserId = userId);
    try {
      await service.updatePayoutHold(userId: userId, enabled: enabled, reason: reason);
      await loadQueue();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => processingUserId = null);
    }
  }

  Future<void> review(Map<String, dynamic> item, String action) async {
    final userId = item['userId']?.toString();
    if (userId == null || userId.isEmpty) return;

    String? reason;
    if (action != 'approve') {
      reasonController.clear();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(action == 'block' ? 'Motivo del bloqueo' : 'Motivo del rechazo'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Explica brevemente la decisión'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reasonController.text.trim()),
              child: Text(action == 'block' ? 'Bloquear' : 'Rechazar'),
            ),
          ],
        ),
      );
      if (reason == null) return;
    }

    setState(() => processingUserId = userId);
    try {
      await service.reviewTraveler(userId: userId, action: action, reason: reason);
      await loadQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'approve' ? 'Traveler aprobado.' : action == 'block' ? 'Traveler bloqueado.' : 'Traveler rechazado.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar la revisión.')),
      );
    } finally {
      if (mounted) setState(() => processingUserId = null);
    }
  }

  String _decisionLabel(String decision) {
    switch (decision) {
      case 'approve':
        return 'Aprobar';
      case 'manual_block_review':
        return 'Bloqueo sugerido';
      case 'approve_with_hold':
        return 'Aprobar con hold';
      case 'reject_or_more_docs':
        return 'Pedir más datos';
      default:
        return 'Revisión manual';
    }
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF59D38C);
    if (score >= 55) return const Color(0xFFFFD27A);
    return const Color(0xFFFF7A7A);
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
                  title: 'Revisión de viajeros',
                  subtitle: 'Score, flags y decisión manual para aprobar, rechazar o bloquear.',
                ),
                const SizedBox(height: 20),
                if (!loading && queue.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppInfoChip(icon: Icons.pending_actions_outlined, label: '${queue.length} por revisar'),
                      const AppInfoChip(icon: Icons.shield_outlined, label: 'Fraude + verificación'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
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
                              icon: Icons.verified_user_outlined,
                              title: 'Sin pendientes',
                              subtitle: 'No hay perfiles de viajero esperando revisión.',
                            )
                          : RefreshIndicator(
                              onRefresh: loadQueue,
                              child: ListView.separated(
                                itemCount: queue.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = queue[index];
                                  final summary = item['summary'];
                                  final flagsSummary = summary is Map<String, dynamic> ? summary['flagsSummary'] : null;
                                  final score = summary is Map<String, dynamic> ? (summary['score'] as num?)?.toInt() ?? 0 : 0;
                                  final trustScore = summary is Map<String, dynamic> ? (summary['trustScore'] as num?)?.toInt() ?? 0 : 0;
                                  final userId = item['userId']?.toString() ?? '';
                                  final isProcessing = processingUserId == userId;
                                  final holdEnabled = summary is Map<String, dynamic> ? summary['payoutHoldEnabled'] == true : false;

                                  return AppGlassSection(
                                    title: item['fullName']?.toString() ?? 'Traveler',
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['email']?.toString() ?? 'Sin correo', style: const TextStyle(color: AppTheme.muted)),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _ScoreTile(
                                                label: 'Score',
                                                value: '$score / 100',
                                                color: _scoreColor(score),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _ScoreTile(
                                                label: 'Trust',
                                                value: '$trustScore / 100',
                                                color: _scoreColor(trustScore),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _ScoreTile(
                                                label: 'Flags',
                                                value: flagsSummary is Map<String, dynamic>
                                                    ? '${flagsSummary['high'] ?? 0}H / ${flagsSummary['medium'] ?? 0}M'
                                                    : '0',
                                                color: const Color(0xFF8AB4FF),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            AppInfoChip(
                                              icon: Icons.flag_outlined,
                                              label: 'Estado: ${summary is Map<String, dynamic> ? summary['currentStatus'] : item['status']}',
                                            ),
                                            AppInfoChip(
                                              icon: Icons.tips_and_updates_outlined,
                                              label: 'Sugerido: ${_decisionLabel(summary is Map<String, dynamic> ? (summary['recommendedDecision']?.toString() ?? 'manual_review') : 'manual_review')}',
                                            ),
                                            AppInfoChip(
                                              icon: Icons.workspace_premium_outlined,
                                              label: 'KYC: ${summary is Map<String, dynamic> ? (summary['suggestedKycTier']?.toString() ?? 'basic') : 'basic'}',
                                            ),
                                            AppInfoChip(
                                              icon: Icons.lock_clock_outlined,
                                              label: summary is Map<String, dynamic> && summary['payoutHoldRecommended'] == true
                                                  ? 'Hold payout sugerido'
                                                  : 'Sin hold sugerido',
                                            ),
                                          ],
                                        ),
                                        if (summary is Map<String, dynamic>) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            'Device trust ${(summary['deviceTrust']?['averageTrustScore'] ?? 0)} • ${(summary['deviceTrust']?['activeDevices'] ?? 0)} device(s) • Assets ${(summary['kycAssets']?['filesAttached'] ?? 0)}',
                                            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                          ),
                                          if (summary['evidence'] is Map<String, dynamic>) ...[
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                if ((summary['evidence']['documentUrl']?.toString() ?? '').isNotEmpty)
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(14),
                                                      child: Image.network(
                                                        '${ApiClient.baseUrl}${summary['evidence']['documentUrl']}',
                                                        height: 110,
                                                        fit: BoxFit.cover,
                                                        headers: SessionService.currentAccessToken == null || SessionService.currentAccessToken!.isEmpty
                                                            ? null
                                                            : {'Authorization': 'Bearer ${SessionService.currentAccessToken!}'},
                                                        errorBuilder: (_, __, ___) => Container(
                                                          height: 110,
                                                          color: AppTheme.surfaceSoft,
                                                          alignment: Alignment.center,
                                                          child: const Text('Documento'),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if ((summary['evidence']['documentUrl']?.toString() ?? '').isNotEmpty &&
                                                    (summary['evidence']['selfieUrl']?.toString() ?? '').isNotEmpty)
                                                  const SizedBox(width: 10),
                                                if ((summary['evidence']['selfieUrl']?.toString() ?? '').isNotEmpty)
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(14),
                                                      child: Image.network(
                                                        '${ApiClient.baseUrl}${summary['evidence']['selfieUrl']}',
                                                        height: 110,
                                                        fit: BoxFit.cover,
                                                        headers: SessionService.currentAccessToken == null || SessionService.currentAccessToken!.isEmpty
                                                            ? null
                                                            : {'Authorization': 'Bearer ${SessionService.currentAccessToken!}'},
                                                        errorBuilder: (_, __, ___) => Container(
                                                          height: 110,
                                                          color: AppTheme.surfaceSoft,
                                                          alignment: Alignment.center,
                                                          child: const Text('Selfie'),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                        if (summary is Map<String, dynamic> && summary['kycChecks'] is List && (summary['kycChecks'] as List).isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          ...((summary['kycChecks'] as List).take(3)).map(
                                            (check) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                '• ${check['kind']} • ${check['status']} • conf ${(check['confidence'] ?? 0)}',
                                                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (summary is Map<String, dynamic> && summary['nextSteps'] is List && (summary['nextSteps'] as List).isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          ...((summary['nextSteps'] as List).take(3)).map(
                                            (step) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                '• ${step.toString()}',
                                                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: isProcessing ? null : () => runKycAnalysis(item),
                                                child: const Text('Re-analizar KYC'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: isProcessing ? null : () => updateHold(item, !holdEnabled),
                                                child: Text(holdEnabled ? 'Liberar hold' : 'Activar hold'),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: isProcessing ? null : () => review(item, 'reject'),
                                                child: const Text('Rechazar'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: isProcessing ? null : () => review(item, 'block'),
                                                child: const Text('Bloquear'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: isProcessing ? null : () => review(item, 'approve'),
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

class _ScoreTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScoreTile({required this.label, required this.value, required this.color});

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
