import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/responsive_helper.dart';

class ImageSelectionDialog extends StatefulWidget {
  final List<String> imageUrls;
  final Function(String) onSelect;

  const ImageSelectionDialog({
    super.key,
    required this.imageUrls,
    required this.onSelect,
  });

  @override
  State<ImageSelectionDialog> createState() => _ImageSelectionDialogState();
}

class _ImageSelectionDialogState extends State<ImageSelectionDialog> {
  String? _selectedUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выберите изображение'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.adultImageGridCount(context),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: widget.imageUrls.length,
          itemBuilder: (context, index) {
            final url = widget.imageUrls[index];
            return GestureDetector(
              onTap: () => setState(() => _selectedUrl = url),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image,
                              color: Colors.red, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            'Фото недоступно',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedUrl == url)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child: Icon(Icons.check_circle,
                          color: Colors.green, size: 28),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _selectedUrl != null
              ? () {
                  widget.onSelect(_selectedUrl!);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Выбрать'),
        ),
      ],
    );
  }
}
