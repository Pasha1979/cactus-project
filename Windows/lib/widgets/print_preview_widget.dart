import 'package:flutter/material.dart';
import '../models/plant.dart';

/// Размеры листов бумаги в миллиметрах
class PaperSize {

  const PaperSize._(this.name, this.widthMm, this.heightMm);
  final String name;
  final double widthMm;
  final double heightMm;

  static const PaperSize a3 = PaperSize._('A3', 297, 420);
  static const PaperSize a4 = PaperSize._('A4', 210, 297);
  static const PaperSize a5 = PaperSize._('A5', 148, 210);

  static const List<PaperSize> values = [a3, a4, a5];
}

enum PageOrientation { portrait, landscape }

/// Виджет предпросмотра макета печати этикеток
class PrintPreviewWidget extends StatelessWidget {

  const PrintPreviewWidget({
    super.key,
    required this.paperSize,
    required this.orientation,
    required this.labelWidthCm,
    required this.labelHeightCm,
    required this.plants,
    this.scale = 0.5,
  });
  final PaperSize paperSize;
  final PageOrientation orientation;
  final double labelWidthCm;
  final double labelHeightCm;
  final List<Plant> plants;
  final double scale;

  /// Рассчитывает количество этикеток на листе
  _LayoutResult _calculateLayout() {
    final pageWidth = orientation == PageOrientation.portrait
        ? paperSize.widthMm
        : paperSize.heightMm;
    final pageHeight = orientation == PageOrientation.portrait
        ? paperSize.heightMm
        : paperSize.widthMm;

    final labelWidth = labelWidthCm * 10; // см в мм
    final labelHeight = labelHeightCm * 10;

    final cols = (pageWidth / labelWidth).floor();
    final rows = (pageHeight / labelHeight).floor();
    final totalLabels = cols * rows;
    final pages = (plants.length / totalLabels).ceil();

    return _LayoutResult(
      cols: cols,
      rows: rows,
      totalLabels: totalLabels,
      pages: pages,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      labelWidth: labelWidth,
      labelHeight: labelHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = _calculateLayout();

    if (layout.cols == 0 || layout.rows == 0) {
      return const Center(
        child: Text(
          'Слишком большой размер этикетки для выбранного листа',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    final pageWidthPx = layout.pageWidth * scale;
    final pageHeightPx = layout.pageHeight * scale;

    return SingleChildScrollView(
      child: Column(
        children: [
          for (int page = 0; page < layout.pages; page++) ...[
            _buildPage(page, layout, pageWidthPx, pageHeightPx),
            const SizedBox(height: 20),
          ],
          _buildSummary(context, layout),
        ],
      ),
    );
  }

  Widget _buildPage(int pageIndex, _LayoutResult layout, double pageWidthPx, double pageHeightPx) {
    final startIndex = pageIndex * layout.totalLabels;
    final endIndex = (startIndex + layout.totalLabels).clamp(0, plants.length);
    final pagePlants = plants.sublist(startIndex, endIndex);

    return Center(
      child: Container(
        width: pageWidthPx,
        height: pageHeightPx,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: CustomPaint(
          size: Size(pageWidthPx, pageHeightPx),
          painter: _LabelGridPainter(
            layout: layout,
            plants: pagePlants,
            scale: scale,
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, _LayoutResult layout) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Информация о макете',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Размер листа: ${paperSize.name}'),
              Text('Ориентация: ${orientation == PageOrientation.portrait ? 'Книжная' : 'Альбомная'}'),
              Text('Этикеток на листе: ${layout.cols} x ${layout.rows} = ${layout.totalLabels}'),
              Text('Всего растений: ${plants.length}'),
              Text('Всего страниц: ${layout.pages}'),
              const SizedBox(height: 8),
              Text(
                'Размер этикетки: ${labelWidthCm.toStringAsFixed(1)} x ${labelHeightCm.toStringAsFixed(1)} см',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayoutResult {

  _LayoutResult({
    required this.cols,
    required this.rows,
    required this.totalLabels,
    required this.pages,
    required this.pageWidth,
    required this.pageHeight,
    required this.labelWidth,
    required this.labelHeight,
  });
  final int cols;
  final int rows;
  final int totalLabels;
  final int pages;
  final double pageWidth;
  final double pageHeight;
  final double labelWidth;
  final double labelHeight;
}

/// Painter для рисования сетки этикеток
class _LabelGridPainter extends CustomPainter {

  _LabelGridPainter({
    required this.layout,
    required this.plants,
    required this.scale,
  });
  final _LayoutResult layout;
  final List<Plant> plants;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    // Рисуем линии сетки (для резки)
    for (int col = 1; col < layout.cols; col++) {
      final x = col * layout.labelWidth * scale;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int row = 1; row < layout.rows; row++) {
      final y = row * layout.labelHeight * scale;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Рисуем рамку вокруг каждой этикетки
    final borderPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int row = 0; row < layout.rows; row++) {
      for (int col = 0; col < layout.cols; col++) {
        final index = row * layout.cols + col;
        if (index >= plants.length) break;

        final x = col * layout.labelWidth * scale;
        final y = row * layout.labelHeight * scale;
        final w = layout.labelWidth * scale;
        final h = layout.labelHeight * scale;

        final rect = Rect.fromLTWH(x, y, w, h);
        canvas.drawRect(rect, borderPaint);

        // Рисуем содержимое этикетки
        _drawLabel(canvas, plants[index], rect);
      }
    }
  }

  void _drawLabel(Canvas canvas, Plant plant, Rect rect) {
    final qrSize = rect.width * 0.6;
    final qrX = rect.left + (rect.width - qrSize) / 2;
    final qrY = rect.top + rect.height * 0.1;

    // Рисуем QR-код (упрощенно - квадрат с текстом)
    final qrPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final qrRect = Rect.fromLTWH(qrX, qrY, qrSize, qrSize);
    canvas.drawRect(qrRect, qrPaint);

    // Рисуем белый квадрат внутри для имитации QR-кода
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final innerSize = qrSize * 0.7;
    final innerRect = Rect.fromLTWH(
      qrX + (qrSize - innerSize) / 2,
      qrY + (qrSize - innerSize) / 2,
      innerSize,
      innerSize,
    );
    canvas.drawRect(innerRect, innerPaint);

    // Рисуем маленькие черные квадраты для имитации QR-кода
    final dotSize = innerSize * 0.15;
    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if ((i + j) % 2 == 0) {
          final dotRect = Rect.fromLTWH(
            innerRect.left + i * dotSize * 2,
            innerRect.top + j * dotSize * 2,
            dotSize,
            dotSize,
          );
          canvas.drawRect(dotRect, dotPaint);
        }
      }
    }

    // Рисуем название растения под QR-кодом
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: rect.height * 0.08,
      fontWeight: FontWeight.bold,
    );
    final textSpan = TextSpan(text: plant.latinName, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: rect.width * 0.9);
    textPainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - textPainter.width) / 2,
        qrY + qrSize + rect.height * 0.05,
      ),
    );

    // Рисуем ID растения
    final idStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: rect.height * 0.06,
    );
    final idSpan = TextSpan(text: plant.displayId, style: idStyle);
    final idPainter = TextPainter(
      text: idSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    idPainter.layout(maxWidth: rect.width * 0.9);
    idPainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - idPainter.width) / 2,
        qrY + qrSize + rect.height * 0.05 + textPainter.height + 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
