import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';

class ShipmentTicketService {
  const ShipmentTicketService();

  String maskedId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '----';
    return trimmed.length <= 4 ? trimmed.toUpperCase() : trimmed.substring(trimmed.length - 4).toUpperCase();
  }

  Future<Uint8List> generatePrintablePDF(List<ShipmentModel> shipments) async {
    final document = pw.Document();

    for (final shipment in shipments) {
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch),
          margin: const pw.EdgeInsets.all(16),
          build: (context) => _buildTicketPage(shipment),
        ),
      );
    }

    return document.save();
  }

  pw.Widget _buildTicketPage(ShipmentModel shipment) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Ticket #${maskedId(shipment.id)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: shipment.id,
                width: 54,
                height: 54,
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _row('Peso', shipment.peso == null ? 'Pendiente' : '${shipment.peso!.toStringAsFixed(1)} lbs'),
          _row('Remitente', shipment.remitenteNombre.isEmpty ? 'Pendiente' : shipment.remitenteNombre),
          _row('Destinatario', shipment.receptorNombre.isEmpty ? 'Pendiente' : shipment.receptorNombre),
          _row('Dirección', shipment.receptorDireccion.isEmpty ? 'Pendiente' : shipment.receptorDireccion),
          pw.Spacer(),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(14),
              color: PdfColors.grey200,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TOTAL A COBRAR', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('\$${shipment.valor.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 74, child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }

  Future<void> printBytes(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> openReceiptPdf(ShipmentModel shipment) async {
    final bytes = await generatePrintablePDF([shipment]);
    await Printing.layoutPdf(
      name: 'ticket_${maskedId(shipment.id)}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  Future<void> printShipments(List<ShipmentModel> shipments) async {
    final bytes = await generatePrintablePDF(shipments);
    await printBytes(bytes);
  }
}
