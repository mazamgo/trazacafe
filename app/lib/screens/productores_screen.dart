import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'equipo_screen.dart';
import 'nuevo_productor_screen.dart';
import 'productor_screen.dart';

/// Pantalla principal del técnico: productores de su cooperativa.
class ProductoresScreen extends ConsumerWidget {
  const ProductoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoSyncProvider);
    final productores = ref.watch(productoresProvider);
    final sesion = ref.watch(sesionProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productores'),
        actions: [
          const BotonSincronizar(),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              if (sesion != null)
                PopupMenuItem(
                  enabled: false,
                  child: Text('${sesion.email}\n${sesion.esAdmin ? 'Administrador' : 'Técnico'}'),
                ),
              if (sesion?.esAdmin ?? false)
                PopupMenuItem(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EquipoScreen()),
                  ),
                  child: const Text('Equipo'),
                ),
              PopupMenuItem(
                onTap: () => ref.read(authServiceProvider).cerrarSesion(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: productores.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) => lista.isEmpty
            ? const Center(child: Text('Aún no hay productores. Toca + para agregar.'))
            : ListView.separated(
                itemCount: lista.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final x = lista[i];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(x.productor.nombre),
                    subtitle: Text([
                      if (x.productor.comunidad != null) x.productor.comunidad!,
                      '${x.fincas} ${x.fincas == 1 ? 'finca' : 'fincas'}',
                    ].join(' · ')),
                    trailing: x.productor.sincronizado
                        ? null
                        : const Icon(Icons.cloud_upload, color: Colors.orange),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProductorScreen(productor: x.productor),
                    )),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo productor',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NuevoProductorScreen()),
        ),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

/// Botón de la barra con la cantidad de registros sin enviar.
class BotonSincronizar extends ConsumerStatefulWidget {
  const BotonSincronizar({super.key});

  @override
  ConsumerState<BotonSincronizar> createState() => _BotonSincronizarState();
}

class _BotonSincronizarState extends ConsumerState<BotonSincronizar> {
  bool _enviando = false;

  Future<void> _sincronizar() async {
    setState(() => _enviando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(syncServiceProvider).sincronizar();
      mensajero.showSnackBar(SnackBar(
        content: Text([
          if (r.enviados > 0) 'Enviados ${r.enviados} registros.',
          if (r.fotosSubidas > 0) 'Subidas ${r.fotosSubidas} fotos.',
          if (r.errorFotos != null) 'Algunas fotos no se subieron: ${r.errorFotos}',
          if (r.enviados == 0 && r.fotosSubidas == 0 && r.errorFotos == null) 'Todo está al día.',
        ].join(' ')),
      ));
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo sincronizar: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = ref.watch(pendientesProvider).value ?? 0;
    return IconButton(
      tooltip: 'Sincronizar',
      onPressed: _enviando ? null : _sincronizar,
      icon: _enviando
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Badge(
              isLabelVisible: pendientes > 0,
              label: Text('$pendientes'),
              child: const Icon(Icons.sync),
            ),
    );
  }
}
