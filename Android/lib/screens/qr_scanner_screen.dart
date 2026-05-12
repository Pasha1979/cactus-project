import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/providers.dart';

/// Экран сканирования QR-кодов с камеры
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanning = true;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    context.read<QrCodeProvider>().loadScanHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать QR-код'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Камера
          MobileScanner(
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),

          // Затемнение сверху и снизу
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.3],
                ),
              ),
            ),
          ),

          // Рамка сканирования
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Наведите камеру на QR-код',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Индикатор сканирования
          if (!_isScanning)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;

    final code = barcode.rawValue!;
    if (code == _lastScannedCode) return; // Не сканировать один и тот же код

    _lastScannedCode = code;
    setState(() {
      _isScanning = false;
    });

    _handleScannedCode(code);
  }

  Future<void> _handleScannedCode(String code) async {
    final plantCrudProvider = context.read<PlantCrudProvider>();
    final qrCodeProvider = context.read<QrCodeProvider>();
    final plant = qrCodeProvider.findPlantByQRCode(plantCrudProvider.plants, code);

    if (mounted) {
      if (plant != null) {
        // Растение найдено - добавляем в историю и открываем карточку
        await qrCodeProvider.addToScanHistory(plant.permanentId);
        if (!mounted) return;
        context.replace(
          '/plant/${plant.permanentId}',
          extra: plant,
        );
      } else {
        // Растение не найдено
        _showErrorDialog(
          'QR-код не найден',
          'Растение с таким QR-кодом не найдено в базе.',
        );
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isScanning = true;
                _lastScannedCode = null;
              });
            },
            child: const Text('Попробовать снова'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
