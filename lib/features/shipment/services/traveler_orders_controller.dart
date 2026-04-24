import 'package:flutter/foundation.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/label_history_service.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/shipment/services/shipment_ticket_service.dart';

class TravelerOrdersController {
  TravelerOrdersController({
    ShipmentService? shipmentService,
    ShipmentTicketService? ticketService,
    LabelHistoryService? historyService,
  })  : _shipmentService = shipmentService ?? ShipmentService(),
        _ticketService = ticketService ?? const ShipmentTicketService(),
        _historyService = historyService ?? const LabelHistoryService();

  final ShipmentService _shipmentService;
  final ShipmentTicketService _ticketService;
  final LabelHistoryService _historyService;

  ValueNotifier<List<LabelHistoryEntry>> historyNotifier = ValueNotifier<List<LabelHistoryEntry>>(const []);

  Future<List<ShipmentModel>> loadShipments() {
    return _shipmentService.getMyShipments();
  }

  Future<void> loadHistory() async {
    historyNotifier.value = await _historyService.loadHistory();
  }

  Future<void> printAllSelected(List<ShipmentModel> shipments) async {
    if (shipments.isEmpty) return;

    final bytes = await _ticketService.generatePrintablePDF(shipments);
    final saved = await _historyService.savePdf(
      bytes,
      fileName: 'labels_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    historyNotifier.value = saved;
    await _ticketService.printBytes(bytes);

    for (final shipment in shipments) {
      if (shipment.estado == 'assigned') {
        await _shipmentService.updateStatus(shipment.id, 'picked_up');
      }
    }
  }

  Future<void> confirmLoad(ShipmentModel shipment) async {
    if (shipment.estado == 'assigned') {
      await _shipmentService.updateStatus(shipment.id, 'picked_up');
    }
  }

  Future<void> openReceipt(ShipmentModel shipment) {
    return _ticketService.openReceiptPdf(shipment);
  }
}
