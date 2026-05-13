import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// TODO(окружение): import 'package:printing/printing.dart'; // Временно отключено из-за ошибки сборки pdfium
import 'package:path_provider/path_provider.dart';
import '../models/plant.dart';
import '../models/qr_code_file.dart';
import '../presentation/providers/providers.dart';
import '../widgets/print_preview_widget.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class PrintSettingsScreen extends StatefulWidget {
  final List<Plant> plantsToPrint;

  const PrintSettingsScreen({super.key, required this.plantsToPrint});

  @override
  PrintSettingsScreenState createState() => PrintSettingsScreenState();
}

class PrintSettingsScreenState extends State<PrintSettingsScreen> {
  PaperSize _paperSize = PaperSize.a4;
  PageOrientation _orientation = PageOrientation.portrait;
  double _labelWidthCm = 6.0;
  double _labelHeightCm = 4.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Печать QR этикеток'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Сохранить в PDF',
            onPressed: _savePdf,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Печать',
            onPressed: _printPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSettingsPanel(),
          const Divider(),
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.all(16),
              child: PrintPreviewWidget(
                paperSize: _paperSize,
                orientation: _orientation,
                labelWidthCm: _labelWidthCm,
                labelHeightCm: _labelHeightCm,
                plants: widget.plantsToPrint,
                scale: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildDropdown<PaperSize>(
            'Формат',
            _paperSize,
            PaperSize.values,
            (size) => size.name,
            (value) => setState(() => _paperSize = value),
          ),
          _buildDropdown<PageOrientation>(
            'Ориентация',
            _orientation,
            PageOrientation.values,
            (o) => o == PageOrientation.portrait ? 'Книжная' : 'Альбомная',
            (value) => setState(() => _orientation = value),
          ),
          _buildSizeInput('Ширина (см)', _labelWidthCm, (v) => _labelWidthCm = v),
          _buildSizeInput('Высота (см)', _labelHeightCm, (v) => _labelHeightCm = v),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T value,
    List<T> items,
    String Function(T) display,
    void Function(T) onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        DropdownButton<T>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(display(item)),
          ),).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ],
    );
  }

  Widget _buildSizeInput(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(
          width: 60,
          child: TextField(
            controller: TextEditingController(text: value.toStringAsFixed(1)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            onSubmitted: (text) {
              final v = double.tryParse(text.replaceAll(',', '.'));
              if (v != null && v > 0) {
                setState(() => onChanged(v));
              }
            },
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _savePdf() async {
    final qrProvider = context.read<QrCodeProvider>();
    final pdf = await _generatePdf();

    // Формируем понятное имя файла: qr_labels_2024-05-09_15-30-00.pdf
    final now = DateTime.now();
    final fileName =
        'qr_labels_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.pdf';

    // Получаем директорию для сохранения (Documents для Windows/Android)
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(await pdf.save());

    // Сохраняем метаданные о файле
    final qrFile = QRCodeFile(
      id: const Uuid().v4(),
      fileName: fileName,
      filePath: file.path,
      createdAt: now,
      plantIds: widget.plantsToPrint.map((p) => p.permanentId).toList(),
      pageFormat: _paperSize.name,
      orientation: _orientation.name,
      labelWidthCm: _labelWidthCm,
      labelHeightCm: _labelHeightCm,
    );
    await qrProvider.saveQRCodeFile(qrFile);

    if (mounted) {
      _showSaveSuccessDialog(file.path);
    }
  }

  void _showSaveSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Файл сохранён'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PDF-файл с QR-этикетками сохранён. Вы можете распечатать его позже.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _printPdf() async {
    final pdf = await _generatePdf();

    // TODO(окружение): Временно отключена печать из-за ошибки сборки pdfium
    // await Printing.layoutPdf(
    //   onLayout: (format) => pdf.save(),
    // );

    // Вместо печати сохраняем PDF файл
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/qr_labels_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF сохранен: ${file.path}')),
    );
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    final pageWidthMm = _orientation == PageOrientation.portrait
        ? _paperSize.widthMm
        : _paperSize.heightMm;
    final pageHeightMm = _orientation == PageOrientation.portrait
        ? _paperSize.heightMm
        : _paperSize.widthMm;

    final labelWidthMm = _labelWidthCm * 10;
    final labelHeightMm = _labelHeightCm * 10;

    final cols = (pageWidthMm / labelWidthMm).floor();
    final rows = (pageHeightMm / labelHeightMm).floor();
    final labelsPerPage = cols * rows;

    if (labelsPerPage == 0) {
      throw Exception('Слишком большой размер этикетки');
    }

    final totalPages = (widget.plantsToPrint.length / labelsPerPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final startIdx = page * labelsPerPage;
      final endIdx = (startIdx + labelsPerPage).clamp(0, widget.plantsToPrint.length);
      final pagePlants = widget.plantsToPrint.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            pageWidthMm * PdfPageFormat.mm,
            pageHeightMm * PdfPageFormat.mm,
          ),
          margin: const pw.EdgeInsets.all(0),
          build: (context) {
            return pw.GridView(
              crossAxisCount: cols,
              childAspectRatio: labelWidthMm / labelHeightMm,
              children: pagePlants.map((plant) => _buildLabel(plant, labelWidthMm, labelHeightMm)).toList(),
            );
          },
        ),
      );
    }

    return pdf;
  }

  pw.Widget _buildLabel(Plant plant, double widthMm, double heightMm) {
    final qrData = plant.qrCode?.toQRCodeData() ?? '${plant.displayId}|${plant.latinName}';

    return pw.Container(
      width: widthMm * PdfPageFormat.mm,
      height: heightMm * PdfPageFormat.mm,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
      ),
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: (widthMm * 0.6) * PdfPageFormat.mm,
            height: (widthMm * 0.6) * PdfPageFormat.mm,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            plant.latinName,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
          pw.Text(
            plant.displayId,
            style: pw.TextStyle(fontSize: 6, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }
}
