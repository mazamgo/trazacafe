import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/api_client.dart';
import 'finca_screen.dart' show fecha;
import 'lotes_screen.dart' show kgTexto;
import 'nuevo_contenedor_screen.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Contenedores de exportación: agrupan lotes de un mismo cultivo (solo
/// administradores; requiere señal).
class ContenedoresScreen extends ConsumerWidget {
  const ContenedoresScreen({super.key});

  Future<void> _nuevo(BuildContext context, WidgetRef ref) async {
    final x = await Navigator.of(context).push<Exportacion>(
      MaterialPageRoute(builder: (_) => const NuevoContenedorScreen()),
    );
    if (x == null || !context.mounted) return;
    ref.invalidate(exportacionesProvider);
    ref.invalidate(lotesProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Contenedor ${x.codigo} creado.')));
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Exportacion x,
  ) async {
    final cambios = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _DialogoDatos(exportacion: x),
    );
    if (cambios == null || cambios.isEmpty || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).cambiarExportacion(x.id, cambios);
      ref.invalidate(exportacionesProvider);
      mensajero.showSnackBar(
        SnackBar(content: Text('Contenedor ${x.codigo} actualizado.')),
      );
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  Future<void> _deshacer(
    BuildContext context,
    WidgetRef ref,
    Exportacion x,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Deshacer el contenedor ${x.codigo}?'),
        content: const Text(
          'Sus lotes quedan libres para otro contenedor. No se borra ningún lote.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Deshacer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).eliminarExportacion(x.id);
      ref.invalidate(exportacionesProvider);
      ref.invalidate(lotesProvider);
      mensajero.showSnackBar(
        SnackBar(content: Text('Contenedor ${x.codigo} deshecho.')),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo deshacer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(exportacionesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Contenedores')),
      body: lista.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudieron cargar los contenedores: $e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(exportacionesProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (xs) => RefreshIndicator(
          onRefresh: () => ref.refresh(exportacionesProvider.future),
          child: xs.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no hay contenedores. Un contenedor agrupa lotes de un mismo '
                        'cultivo para un comprador; de él sale el paquete EUDR.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: EdgeInsets.only(
                    bottom: 96 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    for (final x in xs)
                      _TarjetaContenedor(
                        exportacion: x,
                        onEditar: x.abierta
                            ? () => _editar(context, ref, x)
                            : null,
                        onDeshacer: x.abierta
                            ? () => _deshacer(context, ref, x)
                            : null,
                      ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevo(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Contenedor'),
      ),
    );
  }
}

class _TarjetaContenedor extends StatelessWidget {
  const _TarjetaContenedor({
    required this.exportacion,
    required this.onEditar,
    required this.onDeshacer,
  });

  final Exportacion exportacion;
  final VoidCallback? onEditar;
  final VoidCallback? onDeshacer;

  @override
  Widget build(BuildContext context) {
    final x = exportacion;
    final c = cultivoDe(x.cultivo);
    final pequeno = Theme.of(context).textTheme.bodySmall;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ExpansionTile(
        leading: Icon(c.icono, color: c.colorUi),
        title: Text('${x.codigo} · ${kgTexto(x.kg)} kg'),
        subtitle: Text(
          '${x.comprador} · ${x.destino}\n'
          '${x.contenedor ?? 'Sin número de contenedor'}'
          '${x.abierta ? '' : ' · cerrado'}',
        ),
        trailing: x.fincasSinVerde > 0
            ? const Icon(Icons.satellite_alt, color: Colors.orange)
            : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Origen: ${x.fincas} ${x.fincas == 1 ? 'finca' : 'fincas'} '
            '(${x.areaOficialHa.toStringAsFixed(2)} ha), ${x.entregas} '
            '${x.entregas == 1 ? 'entrega' : 'entregas'}',
          ),
          if (x.fincasSinVerde > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${x.fincasSinVerde} ${x.fincasSinVerde == 1 ? 'finca' : 'fincas'} sin chequeo '
                'satelital verde: el paquete EUDR no se podrá cerrar hasta revisarlas.',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          Text(
            'Embarque: ${x.fechaEmbarque == null ? 'sin fecha' : fecha(x.fechaEmbarque!)} · '
            'DDS: ${x.ddsRef ?? 'pendiente'}',
            style: pequeno,
          ),
          const Divider(height: 20),
          for (final l in x.lotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${l.codigo} · ${kgTexto(l.kg)} kg '
                '${c.nombreEstado(l.estado).toLowerCase()} · ${l.temporada}',
              ),
            ),
          if (x.abierta)
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDeshacer,
                  icon: const Icon(Icons.undo),
                  label: const Text('Deshacer'),
                ),
                TextButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar datos'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Datos que se completan después: número de contenedor, DDS, embarque.
/// Devuelve solo lo que cambió (`null` = borrar ese dato).
class _DialogoDatos extends StatefulWidget {
  const _DialogoDatos({required this.exportacion});

  final Exportacion exportacion;

  @override
  State<_DialogoDatos> createState() => _DialogoDatosState();
}

class _DialogoDatosState extends State<_DialogoDatos> {
  late final _comprador = TextEditingController(
    text: widget.exportacion.comprador,
  );
  late final _destino = TextEditingController(text: widget.exportacion.destino);
  late final _contenedor = TextEditingController(
    text: widget.exportacion.contenedor ?? '',
  );
  late final _dds = TextEditingController(
    text: widget.exportacion.ddsRef ?? '',
  );
  late DateTime? _embarque = widget.exportacion.fechaEmbarque;

  @override
  void dispose() {
    for (final c in [_comprador, _destino, _contenedor, _dds]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _cambios() {
    final x = widget.exportacion;
    String? vacioNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return {
      if (_comprador.text.trim() != x.comprador &&
          _comprador.text.trim().isNotEmpty)
        'comprador': _comprador.text.trim(),
      if (_destino.text.trim() != x.destino && _destino.text.trim().isNotEmpty)
        'destino': _destino.text.trim(),
      if (vacioNull(_contenedor) != x.contenedor)
        'contenedor': vacioNull(_contenedor),
      if (vacioNull(_dds) != x.ddsRef) 'ddsRef': vacioNull(_dds),
      if (_embarque != x.fechaEmbarque)
        'fechaEmbarque': _embarque == null ? null : _iso(_embarque!),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Contenedor ${widget.exportacion.codigo}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _comprador,
              decoration: const InputDecoration(labelText: 'Comprador'),
            ),
            TextField(
              controller: _destino,
              decoration: const InputDecoration(labelText: 'Destino'),
            ),
            TextField(
              controller: _contenedor,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Número de contenedor',
                hintText: 'p. ej. MSCU1234565',
              ),
            ),
            TextField(
              controller: _dds,
              decoration: const InputDecoration(
                labelText: 'Referencia de la DDS (TRACES)',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de embarque'),
              subtitle: Text(
                _embarque == null ? 'Sin fecha' : fecha(_embarque!),
              ),
              trailing: _embarque == null
                  ? null
                  : IconButton(
                      tooltip: 'Quitar fecha',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _embarque = null),
                    ),
              onTap: () async {
                final hoy = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _embarque ?? hoy,
                  firstDate: DateTime(hoy.year - 1),
                  lastDate: DateTime(hoy.year + 2),
                );
                if (d != null) setState(() => _embarque = d);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _cambios()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
