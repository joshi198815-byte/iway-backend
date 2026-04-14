import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/admin/services/admin_ledger_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class AdminLedgerScreen extends StatefulWidget {
  const AdminLedgerScreen({super.key});

  @override
  State<AdminLedgerScreen> createState() => _AdminLedgerScreenState();
}

class _AdminLedgerScreenState extends State<AdminLedgerScreen> {
  final service = AdminLedgerService();
  final travelerIdController = TextEditingController();

  bool loading = false;
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> ledger = [];

  @override
  void dispose() {
    travelerIdController.dispose();
    super.dispose();
  }

  Future<void> loadLedger() async {
    final travelerId = travelerIdController.text.trim();
    if (travelerId.isEmpty) return;

    setState(() => loading = true);
    try {
      final results = await Future.wait([
        service.getTravelerSummary(travelerId),
        service.getTravelerLedger(travelerId),
      ]);
      if (!mounted) return;
      final ledgerData = results[1];
      setState(() {
        summary = results[0];
        final raw = ledgerData['entries'];
        ledger = raw is List
            ? raw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
            : [];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el ledger financiero.')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> createAdjustment() async {
    final travelerId = travelerIdController.text.trim();
    if (travelerId.isEmpty) return;

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String direction = 'credit';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Ajuste manual de ledger'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: direction,
                decoration: const InputDecoration(labelText: 'Tipo de ajuste'),
                items: const [
                  DropdownMenuItem(value: 'credit', child: Text('Crédito, reduce deuda')),
                  DropdownMenuItem(value: 'debit', child: Text('Débito, aumenta deuda')),
                ],
                onChanged: (value) => setModalState(() => direction = value ?? 'credit'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto (USD)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción operativa'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aplicar')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido.')));
      return;
    }

    try {
      await service.createAdjustment(
        travelerId: travelerId,
        direction: direction,
        amount: amount,
        description: descriptionController.text.trim(),
      );
      await loadLedger();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajuste manual registrado.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar el ajuste manual.')),
      );
    }
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _directionLabel(String direction) {
    return direction == 'credit' ? 'Crédito' : 'Débito';
  }

  @override
  Widget build(BuildContext context) {
    final currentDebt = (summary?['currentDebt'] as num?)?.toDouble() ?? 0;

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
                title: 'Ledger financiero',
                subtitle: 'Vista operativa para deuda, movimientos y ajustes manuales por traveler.',
              ),
              const SizedBox(height: 20),
              AppGlassSection(
                title: 'Buscar traveler',
                child: Column(
                  children: [
                    TextField(
                      controller: travelerIdController,
                      decoration: const InputDecoration(labelText: 'Traveler ID'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading ? null : loadLedger,
                            child: const Text('Cargar ledger'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loading ? null : createAdjustment,
                            child: const Text('Ajuste manual'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (summary != null) ...[
                AppGlassSection(
                  title: 'Resumen financiero',
                  child: Row(
                    children: [
                      Expanded(child: _MetricTile(label: 'Deuda actual', value: _money(currentDebt))),
                      const SizedBox(width: 12),
                      Expanded(child: _MetricTile(label: 'Cutoff', value: summary?['preferredCutoffLabel']?.toString() ?? '-')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ledger.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Sin movimientos cargados',
                            subtitle: 'Busca un traveler para ver su ledger financiero y registrar ajustes manuales.',
                          )
                        : ListView.separated(
                            itemCount: ledger.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = ledger[index];
                              return AppGlassSection(
                                title: item['description']?.toString() ?? 'Movimiento',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['kind']} • ${_directionLabel(item['direction']?.toString() ?? 'debit')}',
                                      style: const TextStyle(color: AppTheme.muted),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(child: _MetricTile(label: 'Monto', value: _money(item['amount']))),
                                        const SizedBox(width: 12),
                                        Expanded(child: _MetricTile(label: 'Balance', value: _money(item['balanceAfter']))),
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
