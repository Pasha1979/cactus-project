import 'package:flutter/material.dart';
import '../../../../models/plant.dart';

class SynonymsSection extends StatelessWidget {

  const SynonymsSection({super.key, required this.plant});
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final synonymsText = plant.synonyms ?? 'Синонимы не указаны';
    final synonymsList = synonymsText.split('\n');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.compare_arrows, color: Colors.green),
        title: const Text(
          'Синонимы',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: synonymsList.length == 1
                ? Text(
                    synonymsText,
                    style: const TextStyle(fontSize: 16),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: synonymsList
                        .map((syn) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                syn,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),)
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
