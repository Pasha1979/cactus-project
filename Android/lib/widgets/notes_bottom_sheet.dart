import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/plant.dart';
import '../presentation/providers/providers.dart';

class NotesBottomSheet extends StatefulWidget {
  const NotesBottomSheet({super.key, required this.plant});
  final Plant plant;

  @override
  State<NotesBottomSheet> createState() => _NotesBottomSheetState();
}

class _NotesBottomSheetState extends State<NotesBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final notes = List<Note>.from(widget.plant.notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // новые сверху

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Заметки к ${widget.plant.latinName}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold,),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: notes.isEmpty
                    ? const Center(
                        child: Text('Заметок пока нет',
                            style: TextStyle(fontSize: 16, color: Colors.grey),),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text(note.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,),),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('dd.MM.yyyy HH:mm')
                                        .format(note.createdAt),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey,),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(note.text),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue,),
                                    onPressed: () => _editNote(note),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red,),
                                    onPressed: () => _confirmDelete(note),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить заметку'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: _addNote,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // === Методы добавления/редактирования/удаления ===
  void _addNote() => _showNoteEditor(null);
  void _editNote(Note note) => _showNoteEditor(note);

  void _showNoteEditor(Note? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final textCtrl = TextEditingController(text: existing?.text ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              existing == null ? 'Новая заметка' : 'Редактировать заметку',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Тема / заголовок', border: OutlineInputBorder(),),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                  labelText: 'Текст заметки', border: OutlineInputBorder(),),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена'),),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty ||
                        textCtrl.text.trim().isEmpty) {
                      return; // ← добавили фигурные скобки
                    }
                    final provider =
                        context.read<PlantCrudProvider>();
                    final now = DateTime.now();

                    if (existing == null) {
                      final newNote = Note(
                        id: const Uuid().v4(),
                        title: titleCtrl.text.trim(),
                        text: textCtrl.text.trim(),
                        createdAt: now,
                      );
                      final updated = List<Note>.from(widget.plant.notes)
                        ..add(newNote);
                      provider.updatePlant(widget.plant.permanentId,
                          widget.plant.copyWith(notes: updated),);
                    } else {
                      final updated = widget.plant.notes.map((n) {
                        if (n.id == existing.id) {
                          return Note(
                              id: n.id,
                              title: titleCtrl.text.trim(),
                              text: textCtrl.text.trim(),
                              createdAt: n.createdAt,);
                        }
                        return n;
                      }).toList();
                      provider.updatePlant(widget.plant.permanentId,
                          widget.plant.copyWith(notes: updated),);
                    }
                    provider.savePlants();
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _confirmDelete(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена'),),
          TextButton(
            onPressed: () {
              final provider =
                  context.read<PlantCrudProvider>();
              final updated =
                  widget.plant.notes.where((n) => n.id != note.id).toList();
              provider.updatePlant(widget.plant.permanentId,
                  widget.plant.copyWith(notes: updated),);
              provider.savePlants();
              Navigator.pop(ctx);
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

