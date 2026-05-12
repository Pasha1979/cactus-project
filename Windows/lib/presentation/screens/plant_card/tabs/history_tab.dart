import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/plant.dart';
import '../../../../widgets/notes_bottom_sheet.dart';

class HistoryTab extends StatelessWidget {
  final Plant plant;
  final VoidCallback? onNotesChanged;

  const HistoryTab({
    super.key,
    required this.plant,
    this.onNotesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_note, color: Colors.green),
            title: const Text('Заметки'),
            subtitle: Text('${plant.notes.length} заметок'),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => NotesBottomSheet(plant: plant),
              ).then((_) => onNotesChanged?.call());
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.purple),
            title: const Text('Подробная статистика'),
            onTap: () => context.push(
              '/plant-statistics',
              extra: plant,
            ),
          ),
        ],
      ),
    );
  }
}
