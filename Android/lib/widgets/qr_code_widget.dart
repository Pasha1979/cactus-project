import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/plant.dart';

/// Виджет для отображения QR кода растения
class QRCodeWidget extends StatelessWidget {

  const QRCodeWidget({
    super.key,
    required this.plant,
    this.size = 200,
    this.showName = true,
  });
  final Plant plant;
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    if (plant.qrCode == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'QR код не создан',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: QrImageView(
            data: plant.qrCode!.qrData,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            errorStateBuilder: (context, error) {
              return Container(
                width: size,
                height: size,
                color: Colors.white,
                child: Center(
                  child: Text(
                    'Ошибка генерации QR',
                    style: TextStyle(color: Colors.red, fontSize: size * 0.08),
                  ),
                ),
              );
            },
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 8),
          Text(
            plant.latinName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            plant.displayId,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Иконка-индикатор наличия QR кода (для списка растений)
class QRCodeIndicator extends StatelessWidget {

  const QRCodeIndicator({
    super.key,
    required this.hasQRCode,
    this.size = 16,
  });
  final bool hasQRCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!hasQRCode) return const SizedBox.shrink();

    return Tooltip(
      message: 'QR код создан',
      child: Icon(
        Icons.qr_code,
        size: size,
        color: Colors.green,
      ),
    );
  }
}
