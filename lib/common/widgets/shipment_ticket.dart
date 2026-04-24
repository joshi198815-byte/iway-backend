import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/shared/utils/currency_presenter.dart';

class ShipmentTicket extends StatelessWidget {
  const ShipmentTicket({
    super.key,
    required this.shipment,
    this.onPrint,
    this.onOpenChat,
  });

  final ShipmentModel shipment;
  final VoidCallback? onPrint;
  final VoidCallback? onOpenChat;

  String _maskedId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '----';
    return trimmed.length <= 4 ? trimmed.toUpperCase() : trimmed.substring(trimmed.length - 4).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ticket #${_maskedId(shipment.id)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                onPressed: onOpenChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                tooltip: 'Chat interno',
              ),
              IconButton(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
                tooltip: 'Imprimir',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 10),
          _TicketRow(label: 'Peso', value: shipment.peso == null ? 'Pendiente' : '${shipment.peso!.toStringAsFixed(1)} lbs'),
          const SizedBox(height: 8),
          _TicketRow(label: 'Remitente', value: shipment.remitenteNombre.isEmpty ? 'Pendiente' : shipment.remitenteNombre),
          const SizedBox(height: 8),
          _TicketRow(label: 'Destinatario', value: shipment.receptorNombre.isEmpty ? 'Pendiente' : shipment.receptorNombre),
          const SizedBox(height: 8),
          _TicketRow(label: 'Dirección', value: shipment.receptorDireccion.isEmpty ? 'Pendiente' : shipment.receptorDireccion),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL A COBRAR', style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  CurrencyPresenter.usd(shipment.valor),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CustomPaint(
              painter: _DottedLinePainter(),
              child: const SizedBox(height: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(color: AppTheme.muted)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.muted
      ..strokeWidth = 1;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
