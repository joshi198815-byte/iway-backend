import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _shipmentService = ShipmentService();
  final _scannerController = MobileScannerController();

  bool _handling = false;
  String? _lastCode;

  bool _isHeavyCargo(ShipmentModel shipment) {
    final text = '${shipment.tipo} ${shipment.descripcion ?? ''}'.toLowerCase();
    return text.contains('carro') || text.contains('moto') || text.contains('repuesto');
  }

  bool _needsCarefulHandling(ShipmentModel shipment) {
    final text = '${shipment.tipo} ${shipment.descripcion ?? ''}'.toLowerCase();
    return text.contains('medicina') || text.contains('documento');
  }

  Future<void> _handleCode(String code) async {
    if (_handling || code.trim().isEmpty || _lastCode == code.trim()) return;
    _handling = true;
    _lastCode = code.trim();

    try {
      final shipment = await _shipmentService.getShipmentById(code.trim());
      if (!mounted) return;
      await _showShipmentResult(shipment);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo encontrar el envío escaneado.')));
    } finally {
      _handling = false;
    }
  }

  Future<void> _confirmAction(ShipmentModel shipment) async {
    try {
      if (shipment.estado == 'assigned') {
        await _shipmentService.updateStatus(shipment.id, 'picked_up');
      } else if (shipment.estado == 'picked_up' || shipment.estado == 'in_transit' || shipment.estado == 'in_delivery' || shipment.estado == 'arrived') {
        await _shipmentService.updateStatus(shipment.id, 'delivered');
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estado actualizado desde escaneo.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showShipmentResult(ShipmentModel shipment) {
    final heavy = _isHeavyCargo(shipment);
    final careful = _needsCarefulHandling(shipment);
    final canConfirmLoad = shipment.estado == 'assigned';
    final canConfirmDelivery = shipment.estado == 'picked_up' || shipment.estado == 'in_transit' || shipment.estado == 'in_delivery' || shipment.estado == 'arrived';

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shipment.descripcion?.trim().isNotEmpty == true ? shipment.descripcion!.trim() : shipment.tipo,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('ID ${shipment.id}', style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 12),
            if (heavy)
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
                    const Text('Ficha técnica detallada', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Tipo: ${shipment.tipo}'),
                    Text('Peso: ${shipment.peso?.toStringAsFixed(1) ?? 'Pendiente'} lbs'),
                    Text('Ruta: ${shipment.origen} ➔ ${shipment.destino}'),
                  ],
                ),
              ),
            if (careful) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.45), width: 0.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                    SizedBox(width: 10),
                    Expanded(child: Text('Manejo cuidadoso', style: TextStyle(fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (canConfirmLoad)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmAction(shipment),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Confirmar Carga'),
                ),
              ),
            if (canConfirmDelivery)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmAction(shipment),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirmar Entrega'),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/tracking', arguments: shipment.id);
                },
                child: const Text('Ver detalle completo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Escanear paquete')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
              if (barcode != null) {
                _handleCode(barcode);
              }
            },
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
              ),
              child: const Text(
                'Apunta al QR del ticket para abrir el envío al instante.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
