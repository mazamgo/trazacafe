import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'nueva_finca_screen.dart';

class FincasScreen extends ConsumerWidget {
  const FincasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fincas = ref.watch(fincasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fincas registradas')),
      body: fincas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) => lista.isEmpty
            ? const Center(child: Text('Aún no hay fincas. Toca + para agregar.'))
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
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NuevaFincaScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
