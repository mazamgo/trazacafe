import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import 'nueva_finca_screen.dart';

/// Fincas de un productor.
class ProductorScreen extends ConsumerWidget {
  const ProductorScreen({super.key, required this.productor});

  final Productor productor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fincas = ref.watch(fincasDeProductorProvider(productor.id));

    return Scaffold(
      appBar: AppBar(title: Text(productor.nombre)),
      body: fincas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) => lista.isEmpty
            ? const Center(child: Text('Sin fincas. Toca + para registrar una.'))
            : ListView.separated(
                itemCount: lista.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final f = lista[i];
                  return ListTile(
                    leading: const Icon(Icons.agriculture),
                    title: Text(f.nombre),
                    subtitle: Text('${f.areaHa.toStringAsFixed(2)} ha'),
                    trailing: Icon(
                      f.sincronizado ? Icons.cloud_done : Icons.cloud_upload,
                      color: f.sincronizado ? Colors.green : Colors.orange,
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva finca',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NuevaFincaScreen(productorId: productor.id),
        )),
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }
}
