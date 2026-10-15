import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import '../services/fincas_service.dart';
import 'nueva_finca_screen.dart';

/// Fincas de un productor.
class ProductorScreen extends ConsumerWidget {
  const ProductorScreen({super.key, required this.productor});

  final Productor productor;

  Future<void> _eliminar(BuildContext context, WidgetRef ref, Finca f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar "${f.nombre}"?'),
        content: Text(f.sincronizado
            ? 'Se borrará del celular y del servidor, con sus fotos. Necesitas señal.'
            : 'Se borrará del celular con sus fotos. Todavía no se había enviado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(fincasServiceProvider).eliminar(f);
      mensajero.showSnackBar(SnackBar(content: Text('Se eliminó "${f.nombre}".')));
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

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
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        f.sincronizado ? Icons.cloud_done : Icons.cloud_upload,
                        color: f.sincronizado ? Colors.green : Colors.orange,
                      ),
                      if (FincasService.sePuedeEliminar(f))
                        IconButton(
                          tooltip: 'Eliminar finca',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _eliminar(context, ref, f),
                        ),
                    ]),
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
