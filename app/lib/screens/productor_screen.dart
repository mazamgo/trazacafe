import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/cedula.dart';
import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/fincas_service.dart';
import '../widgets/eliminacion.dart';
import '../widgets/seccion_fotos.dart';
import 'finca_screen.dart';
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
        content: Text(
          f.sincronizado
              ? 'Se borrará del celular y del servidor, con sus fotos. Necesitas señal.'
              : 'Se borrará del celular con sus fotos. Todavía no se había enviado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(fincasServiceProvider).eliminar(f);
      mensajero.showSnackBar(
        SnackBar(content: Text('Se eliminó "${f.nombre}".')),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, Productor p) async {
    final datos = await showDialog<(String, String?, String?)>(
      context: context,
      builder: (_) => _DialogoProductor(productor: p),
    );
    if (datos == null || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(correccionesServiceProvider)
          .corregirProductor(
            p,
            nombre: datos.$1,
            cedula: datos.$2,
            comunidad: datos.$3,
          );
      mensajero.showSnackBar(
        const SnackBar(content: Text('Productor corregido.')),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo corregir: $e')),
      );
    }
  }

  /// El productor pidió en persona que se borren sus datos (solo administradores).
  Future<void> _eliminarDatos(
    BuildContext context,
    WidgetRef ref,
    Productor p,
  ) async {
    if (!await confirmarEliminacionProductor(context, p.nombre) ||
        !context.mounted) {
      return;
    }
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    try {
      final r = await ref
          .read(eliminacionServiceProvider)
          .eliminarProductor(p.id, motivo: 'Lo pidió en persona');
      mensajero.showSnackBar(SnackBar(content: Text(resumenEliminacion(r))));
      if (!r.anonimizado) navegador.pop();
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudieron eliminar los datos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fincas = ref.watch(fincasDeProductorProvider(productor.id));
    final esAdmin = ref.watch(sesionProvider).value?.esAdmin ?? false;
    // El productor de la lista, para ver al instante lo que se corrija.
    final p =
        ref
            .watch(productoresProvider)
            .value
            ?.map((x) => x.productor)
            .where((x) => x.id == productor.id)
            .firstOrNull ??
        productor;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.nombre),
        actions: [
          if (!p.anonimizado)
            IconButton(
              tooltip: 'Corregir datos del productor',
              onPressed: () => _editar(context, ref, p),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (esAdmin && !p.anonimizado && p.sincronizado)
            PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => _eliminarDatos(context, ref, p),
                  child: const Text('Eliminar datos del productor'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.anonimizado)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Sus datos personales se eliminaron'),
                subtitle: Text(
                  'A pedido del productor. Estas fincas tienen entregas en '
                  'lotes o contenedores: el EUDR obliga a guardarlas sin datos '
                  'personales${p.conservarHasta != null ? ' hasta el ${fecha(p.conservarHasta!)}' : ''}.',
                ),
              ),
            )
          else
            SeccionFotos(
              titulo: 'Consentimiento de datos',
              entidadTipo: 'productor',
              entidadId: productor.id,
              tipo: 'consentimiento',
              textoBoton: 'Agregar foto',
              vacio:
                  'No hay foto del consentimiento en este celular '
                  '(si lo registró otro técnico, está en el servidor).',
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Fincas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: fincas.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (lista) => lista.isEmpty
                  ? const Center(
                      child: Text('Sin fincas. Toca + para registrar una.'),
                    )
                  : ListView.separated(
                      itemCount: lista.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final f = lista[i];
                        final cultivo = cultivoDe(f.cultivo);
                        return ListTile(
                          leading: Icon(cultivo.icono, color: cultivo.colorUi),
                          title: Text(f.nombre),
                          subtitle: Text(
                            '${cultivo.nombre} · '
                            '${(f.areaOficialHa ?? f.areaHa).toStringAsFixed(2)} ha',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FincaScreen(fincaId: f.id),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                f.sincronizado
                                    ? Icons.cloud_done
                                    : Icons.cloud_upload,
                                color: f.sincronizado
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              if (FincasService.sePuedeEliminar(f))
                                IconButton(
                                  tooltip: 'Eliminar finca',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _eliminar(context, ref, f),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: p.anonimizado
          ? null
          : FloatingActionButton(
              tooltip: 'Nueva finca',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NuevaFincaScreen(productorId: productor.id),
                ),
              ),
              child: const Icon(Icons.add_location_alt),
            ),
    );
  }
}

/// Nombre, cédula (validada) y comunidad. Devuelve (nombre, cédula, comunidad).
class _DialogoProductor extends StatefulWidget {
  const _DialogoProductor({required this.productor});

  final Productor productor;

  @override
  State<_DialogoProductor> createState() => _DialogoProductorState();
}

class _DialogoProductorState extends State<_DialogoProductor> {
  late final _nombre = TextEditingController(text: widget.productor.nombre);
  late final _cedula = TextEditingController(
    text: widget.productor.cedula ?? '',
  );
  late final _comunidad = TextEditingController(
    text: widget.productor.comunidad ?? '',
  );
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _cedula, _comunidad]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    final cedula = _cedula.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre.');
      return;
    }
    if (cedula.isNotEmpty && normalizarCedula(cedula) == null) {
      setState(
        () => _error = 'La cédula debe tener el formato 001-010190-0001A.',
      );
      return;
    }
    final comunidad = _comunidad.text.trim();
    Navigator.pop(context, (
      nombre,
      cedula.isEmpty ? null : normalizarCedula(cedula),
      comunidad.isEmpty ? null : comunidad,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corregir productor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            TextField(
              controller: _cedula,
              decoration: const InputDecoration(
                labelText: 'Cédula (opcional)',
                hintText: '001-010190-0001A',
              ),
            ),
            TextField(
              controller: _comunidad,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Comunidad (opcional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
