import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/features/payments/services/payment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/services/storage_upload_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/ui/app_operational_banner.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with WidgetsBindingObserver {
  final service = PaymentService();
  final _realtime = RealtimeService.instance;
  final authService = AuthService();
  final storageUploadService = StorageUploadService();
  final amountController = TextEditingController();
  final bankReferenceController = TextEditingController();
  final proofUrlController = TextEditingController();

  bool loading = true;
  double total = 0;
  double commissionPerLb = 0;
  double groundCommissionPercent = 0;
  int selectedCutoffDay = 4;
  bool savingCutoff = false;
  bool submittingTransfer = false;
  StreamSubscription<dynamic>? _syncSubscription;
  List<Map<String, dynamic>> commissions = [];
  List<Map<String, dynamic>> settlements = [];
  List<Map<String, dynamic>> transfers = [];
  List<Map<String, dynamic>> ledger = [];
  Map<String, dynamic>? payoutPolicy;

  double _toAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  double _ledgerCreditsSince(DateTime from) {
    return ledger.fold<double>(0, (sum, item) {
      final occurredAt = _toDate(item['occurredAt'] ?? item['createdAt']);
      final direction = item['direction']?.toString();
      if (occurredAt == null || occurredAt.isBefore(from) || direction != 'credit') {
        return sum;
      }
      return sum + _toAmount(item['amount']);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime.ensureConnected();
    _syncSubscription = _realtime.globalEntitySync.listen((event) {
      if (!mounted) return;
      final payload = event is Map ? event['payload'] : null;
      if (payload is Map && payload['type']?.toString() == 'transfer_review') {
        loadDebtSummary();
      }
    });
    loadDebtSummary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSubscription?.cancel();
    amountController.dispose();
    bankReferenceController.dispose();
    proofUrlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      authService.refreshCurrentUser().then((_) {
        if (mounted) loadDebtSummary();
      }).catchError((_) {});
    }
  }

  Future<void> loadDebtSummary() async {
    try {
      final results = await Future.wait([service.getDebtSummary(), service.getMyTransfers(), service.getMyLedger(), service.getMyPayoutPolicy()]);
      final data = results[0] as Map<String, dynamic>;
      final liveTransfers = results[1] as List<Map<String, dynamic>>;
      final liveLedger = results[2] as List<Map<String, dynamic>>;
      final livePayoutPolicy = results[3] as Map<String, dynamic>;
      final rawCommissions = data['commissions'];
      final rawSettlements = data['settlements'];
      final pricingSettings = data['pricingSettings'];
      final rawTransfers = liveTransfers;
      final rawLedger = liveLedger;

      List<Map<String, dynamic>> normalizeList(dynamic raw) {
        if (raw is! List) return [];
        return raw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
      }

      if (!mounted) return;

      setState(() {
        total = (data['totalPending'] as num?)?.toDouble() ?? 0;
        commissionPerLb = (pricingSettings is Map<String, dynamic>)
            ? (pricingSettings['commissionPerLb'] as num?)?.toDouble() ?? 0
            : 0;
        groundCommissionPercent = (pricingSettings is Map<String, dynamic>)
            ? (pricingSettings['groundCommissionPercent'] as num?)?.toDouble() ?? 0
            : 0;
        selectedCutoffDay = (data['preferredCutoffDay'] as num?)?.toInt() ?? 4;
        commissions = normalizeList(rawCommissions);
        settlements = normalizeList(rawSettlements);
        transfers = normalizeList(rawTransfers);
        ledger = normalizeList(rawLedger);
        payoutPolicy = livePayoutPolicy;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el resumen de deudas.')),
      );
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'due':
        return 'Por vencer';
      case 'overdue':
        return 'Vencida';
      case 'paid':
        return 'Pagada';
      default:
        return status;
    }
  }


  String _cutoffLabel(int day) {
    switch (day) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return 'Jueves';
    }
  }

  Future<void> updateCutoffDay(int? day) async {
    if (day == null || day == selectedCutoffDay || savingCutoff) return;

    setState(() => savingCutoff = true);
    try {
      await service.updateCutoffPreference(day);
      await loadDebtSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tu día de corte ahora es ${_cutoffLabel(day)}.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el día de corte.')),
      );
    } finally {
      if (mounted) {
        setState(() => savingCutoff = false);
      }
    }
  }


  Future<void> submitTransfer() async {
    amountController.text = total > 0 ? total.toStringAsFixed(2) : '';
    bankReferenceController.clear();
    proofUrlController.clear();

    String? uploadedProofUrl;
    bool uploadingProof = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Reportar transferencia'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto transferido (USD)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankReferenceController,
                  decoration: const InputDecoration(labelText: 'Referencia bancaria'),
                ),
                const SizedBox(height: 12),
                if (uploadedProofUrl != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Comprobante cargado correctamente.'),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            '${ApiClient.baseUrl}$uploadedProofUrl',
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            headers: SessionService.currentAccessToken == null || SessionService.currentAccessToken!.isEmpty
                                ? null
                                : {'Authorization': 'Bearer ${SessionService.currentAccessToken!}'},
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: uploadingProof
                            ? null
                            : () async {
                                setModalState(() => uploadingProof = true);
                                try {
                                  final result = await storageUploadService.pickAndUploadTransferProof(
                                    source: ImageSource.gallery,
                                  );
                                  uploadedProofUrl = result?['url']?.toString();
                                  proofUrlController.text = uploadedProofUrl ?? '';
                                } catch (_) {} finally {
                                  setModalState(() => uploadingProof = false);
                                }
                              },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: uploadingProof
                            ? null
                            : () async {
                                setModalState(() => uploadingProof = true);
                                try {
                                  final result = await storageUploadService.pickAndUploadTransferProof(
                                    source: ImageSource.camera,
                                  );
                                  uploadedProofUrl = result?['url']?.toString();
                                  proofUrlController.text = uploadedProofUrl ?? '';
                                } catch (_) {} finally {
                                  setModalState(() => uploadingProof = false);
                                }
                              },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Cámara'),
                      ),
                    ),
                  ],
                ),
                if (uploadingProof) ...[
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(strokeWidth: 2),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido.')),
      );
      return;
    }

    setState(() => submittingTransfer = true);
    try {
      await service.submitTransfer(
        amount: amount,
        weeklySettlementId: settlements.isNotEmpty ? settlements.first['id']?.toString() : null,
        bankReference: bankReferenceController.text,
        proofUrl: proofUrlController.text,
      );
      await authService.refreshCurrentUser();
      await loadDebtSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            proofUrlController.text.isNotEmpty
                ? 'Comprobante subido y enviado para revisión.'
                : 'Transferencia reportada. Queda pendiente de revisión admin.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el comprobante.')),
      );
    } finally {
      if (mounted) setState(() => submittingTransfer = false);
    }
  }

  String _formatTransferStatus(String status) {
    switch (status) {
      case 'submitted':
        return 'En revisión';
      case 'approved':
        return 'Aprobada';
      case 'rejected':
        return 'Rechazada';
      default:
        return status;
    }
  }

  Color _transferStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF59D38C);
      case 'rejected':
        return const Color(0xFFFF8A7A);
      default:
        return const Color(0xFFFFD27A);
    }
  }

  String _formatRule(Map<String, dynamic> item) {
    final ruleType = item['ruleType']?.toString();
    final appliedRate = (item['appliedRate'] as num?)?.toDouble() ?? 0;
    final calculationBase = (item['calculationBase'] as num?)?.toDouble() ?? 0;

    if (ruleType == 'per_lb') {
      return '${calculationBase.toStringAsFixed(2)} lb × \$${appliedRate.toStringAsFixed(2)}';
    }

    return '\$${calculationBase.toStringAsFixed(2)} × ${(appliedRate * 100).toStringAsFixed(2)}%';
  }

  void _showDebtBreakdown() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Detalle de deuda pendiente', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Aquí ves exactamente de qué paquetes sale tu deuda con i-Way.', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 16),
            if (commissions.isEmpty)
              const Text('No tienes deuda pendiente.', style: TextStyle(color: AppTheme.muted))
            else
              ...commissions.map((item) {
                final amount = _toAmount(item['commissionAmount']);
                final shipmentId = item['shipmentId']?.toString() ?? 'Sin envío';
                final status = item['status']?.toString() ?? 'pending';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paquete $shipmentId', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_formatStatus(status), style: const TextStyle(color: AppTheme.muted)),
                          ],
                        ),
                      ),
                      Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBlocked = SessionService.currentUser?.bloqueado == true;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);
    final weekEarnings = _ledgerCreditsSince(weekStart);
    final monthEarnings = _ledgerCreditsSince(monthStart);
    final yearEarnings = _ledgerCreditsSince(yearStart);

    Widget metric({required String label, required String value, VoidCallback? onTap}) {
      final card = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
      );

      return Expanded(
        child: onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: card),
      );
    }

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
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                      const SizedBox(height: 24),
                      const AppPageIntro(
                        title: 'Wallet',
                        subtitle: 'Tus ingresos y tu deuda pendiente, sin ruido visual.',
                      ),
                      const SizedBox(height: 20),
                      if (isBlocked || total > 0) ...[
                        AppOperationalBanner(
                          icon: isBlocked ? Icons.lock_outline_rounded : Icons.account_balance_wallet_outlined,
                          title: isBlocked ? 'Cuenta restringida por deuda' : 'Deuda pendiente con i-Way',
                          message: total > 0
                              ? 'Toca el bloque de deuda para ver exactamente qué paquetes la componen.'
                              : 'Tu cuenta tiene una restricción operativa activa.',
                          tone: isBlocked ? const Color(0xFFFF8A7A) : const Color(0xFFFFD27A),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          metric(label: 'Semana', value: '\$${weekEarnings.toStringAsFixed(2)}'),
                          const SizedBox(width: 10),
                          metric(label: 'Mes', value: '\$${monthEarnings.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          metric(label: 'Año', value: '\$${yearEarnings.toStringAsFixed(2)}'),
                          const SizedBox(width: 10),
                          metric(
                            label: 'Deuda Pendiente i-Way',
                            value: '\$${total.toStringAsFixed(2)}',
                            onTap: _showDebtBreakdown,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AppGlassSection(
                        title: 'Reportar pago',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sube tu comprobante. El reporte viaja al Admin Web para validación manual.',
                              style: TextStyle(color: AppTheme.muted, height: 1.35),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: submittingTransfer ? null : submitTransfer,
                                child: submittingTransfer
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Subir comprobante'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (transfers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        AppGlassSection(
                          title: 'Últimos reportes',
                          child: Column(
                            children: transfers.take(3).map((item) {
                              final amount = _toAmount(item['transferredAmount']);
                              final status = item['status']?.toString() ?? 'submitted';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _formatTransferStatus(status),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _transferStatusColor(status),
                                        ),
                                      ),
                                    ),
                                    Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
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
