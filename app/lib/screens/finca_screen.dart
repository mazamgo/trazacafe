import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/correcciones_service.dart';
import '../services/fincas_service.dart';
import '../widgets/estado_satelital.dart';
import '../widgets/formulario_entrega.dart';
import '../widgets/motivo.dart';
import '../widgets/seccion_fotos.dart';
import 'verificacion_screen.dart';

/// Detalle de una finca: estado satelital, visita de verificación de la
/// temporada, fotos y entregas agrupadas por temporada.
class FincaScreen extends ConsumerWidget {
  const FincaScreen({super.key, required this.fincaId});

  final String fincaId;

  Future<void> _nuevaEntrega(
    BuildContext context,
    WidgetRef ref,
    Finca finca,
  ) async {
    final actual = ref.read(temporadaActualDeProvider(finca.cultivo));
    final visitas =
        ref.read(verificacionesProvider(fincaId)).value ??
        const <Verificacion>[];
    final verificada =
        actual != null && visitas.any((v) => v.temporadaId == actual.id);
    final aviso = finca.deforestacion == 'rojo'
        ? 'El satélite detectó pérdida de bosque en esta finca después de 2020. '
              'Sus entregas no podrán ir en un lote de exportación hasta revisarla.'
        : !verificada
        ? 'Esta finca no tiene la visita de verificación de '
              '${actual?.nombre ?? 'la temporada actual'}. La entrega se guarda, '
              'pero la finca no podrá ir en un lote de exportación hasta verificarla.'
        : null;
    if (aviso != null) {
      final seguir = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: finca.deforestacion == 'rojo' ? Colors.red : Colors.orange,
          ),
          title: const Text('Antes de registrar'),
          content: Text(aviso),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(verificada ? 'Cancelar' : 'Hacer la visita primero'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Registrar de todos modos'),
            ),
          ],
        ),
      );
      if (seguir != true) {
        if (seguir == false && !verificada && context.mounted) {
          _abrirVisita(context, finca);
        }
        return;
      }
    }
    if (!context.mounted) return;
    final accion = await showModalBottomSheet<AccionEntrega>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _formulario(ref, finca),
    );
    if (accion is! GuardarEntrega) return;
    final db = ref.read(databaseProvider);
    final temporada = await db.temporadaDe(
      accion.fecha,
      cultivo: finca.cultivo,
    );
    await db
        .into(db.entregas)
        .insert(
          EntregasCompanion.insert(
            id: const Uuid().v4(),
            fincaId: fincaId,
            kg: accion.kg,
            estado: accion.estado,
            fecha: accion.fecha,
            creadoEn: Value(DateTime.now()),
            temporadaId: Value(temporada?.id),
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrega guardada. Se enviará al sincronizar.'),
        ),
      );
    }
  }

  Future<void> _cambiarCultivo(
    BuildContext context,
    WidgetRef ref,
    Finca finca,
  ) async {
    final cultivos =
        ref.read(cultivosOrganizacionProvider).value ?? const <String>[];
    final nuevo = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Cultivo de la finca'),
        children: [
          for (final cultivo in cultivos.map(cultivoDe))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, cultivo.id),
              child: Row(
                children: [
                  Icon(cultivo.icono, color: cultivo.colorUi),
                  const SizedBox(width: 12),
                  Expanded(child: Text(cultivo.nombre)),
                  if (cultivo.id == finca.cultivo) const Icon(Icons.check),
                ],
              ),
            ),
          if (finca.sincronizado)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text('Necesitas señal: la finca ya se envió.'),
            ),
        ],
      ),
    );
    if (nuevo == null || nuevo == finca.cultivo || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(fincasServiceProvider).cambiarCultivo(finca, nuevo);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            'La finca ahora es de ${cultivoDe(nuevo).nombre.toLowerCase()}.',
          ),
        ),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el cultivo: $e')),
      );
    }
  }

  /// Formulario de entrega con los datos para el aviso de rendimiento:
  /// lo que la finca ya entregó en la temporada (sin [excluir]).
  FormularioEntrega _formulario(
    WidgetRef ref,
    Finca finca, {
    Entrega? inicial,
  }) {
    final cultivo = cultivoDe(finca.cultivo);
    final exportable = cultivo.estados.firstWhere(
      (e) => e.factorExportable == 1,
    );
    final temporadas =
        ref.read(temporadasProvider).value ?? const <Temporada>[];
    final entregas =
        ref.read(entregasProvider(fincaId)).value ?? const <Entrega>[];
    return FormularioEntrega(
      cultivo: cultivo,
      fincaNombre: finca.nombre,
      inicial: inicial,
      areaHa: finca.areaOficialHa ?? finca.areaHa,
      kgExportablesTemporada: (fecha) {
        final t = temporadaVigente(temporadas, fecha, cultivo: cultivo.id);
        if (t == null) return 0;
        return entregas
            .where((e) => e.temporadaId == t.id && e.id != inicial?.id)
            .fold(
              0.0,
              (s, e) => s + cultivo.convertirKg(e.kg, e.estado, exportable.id),
            );
      },
    );
  }

  Future<void> _corregirEntrega(
    BuildContext context,
    WidgetRef ref,
    Finca finca,
    Entrega e,
  ) async {
    final bloqueo = CorreccionesService.bloqueoEntrega(e);
    if (bloqueo != null) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('No se puede corregir'),
          content: Text(bloqueo),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    final accion = await showModalBottomSheet<AccionEntrega>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _formulario(ref, finca, inicial: e),
    );
    if (accion == null || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final servicio = ref.read(correccionesServiceProvider);
    try {
      switch (accion) {
        case GuardarEntrega(
          :final kg,
          :final estado,
          :final fecha,
          :final motivo,
        ):
          await servicio.corregirEntrega(
            e,
            kg: kg,
            estado: estado,
            fecha: fecha,
            motivo: motivo,
          );
          mensajero.showSnackBar(
            const SnackBar(content: Text('Entrega corregida.')),
          );
        case AnularEntrega(:final motivo):
          await servicio.anularEntrega(e, motivo);
          mensajero.showSnackBar(
            const SnackBar(content: Text('Entrega anulada.')),
          );
      }
    } catch (error) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo corregir: $error')),
      );
    }
  }

  Future<void> _editarFinca(
    BuildContext context,
    WidgetRef ref,
    Finca finca,
  ) async {
    final esPunto = (jsonDecode(finca.coordenadasJson) as List).length == 1;
    final cambios = await showDialog<(String, double?, String?)>(
      context: context,
      builder: (_) => _DialogoFinca(finca: finca, esPunto: esPunto),
    );
    if (cambios == null || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(correccionesServiceProvider)
          .corregirFinca(
            finca,
            nombre: cambios.$1,
            areaHa: cambios.$2,
            motivo: cambios.$3,
          );
      mensajero.showSnackBar(const SnackBar(content: Text('Finca corregida.')));
    } catch (error) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo corregir: $error')),
      );
    }
  }

  Future<void> _corregirVisita(
    BuildContext context,
    WidgetRef ref,
    Verificacion v,
  ) async {
    final accion = await showDialog<_AccionVisita>(
      context: context,
      builder: (_) => _DialogoVisita(visita: v),
    );
    if (accion == null || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final servicio = ref.read(correccionesServiceProvider);
    try {
      if (accion.anular != null) {
        await servicio.anularVisita(v, accion.anular!);
        mensajero.showSnackBar(
          const SnackBar(content: Text('Visita anulada.')),
        );
      } else {
        await servicio.corregirVisita(
          v,
          nota: accion.nota,
          fecha: accion.fecha,
          motivo: accion.motivo,
        );
        mensajero.showSnackBar(
          const SnackBar(content: Text('Visita corregida.')),
        );
      }
    } catch (error) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo corregir: $error')),
      );
    }
  }

  void _abrirVisita(BuildContext context, Finca finca) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => VerificacionScreen(finca: finca)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finca = ref.watch(fincaProvider(fincaId)).value;
    final entregas =
        ref.watch(entregasProvider(fincaId)).value ?? const <Entrega>[];
    final visitas =
        ref.watch(verificacionesProvider(fincaId)).value ??
        const <Verificacion>[];
    final temporadas =
        ref.watch(temporadasProvider).value ?? const <Temporada>[];
    final cultivo = cultivoDe(finca?.cultivo ?? cultivoPorDefecto);
    final actual = ref.watch(temporadaActualDeProvider(cultivo.id));
    final esAdmin = ref.watch(sesionProvider).value?.esAdmin ?? false;

    // Entregas por temporada, en el orden de las temporadas (más reciente primero).
    final nombres = {for (final t in temporadas) t.id: t.nombre};
    final grupos = <String?, List<Entrega>>{};
    for (final e in entregas) {
      grupos
          .putIfAbsent(
            nombres.containsKey(e.temporadaId) ? e.temporadaId : null,
            () => [],
          )
          .add(e);
    }
    final orden = [
      for (final t in temporadas)
        if (grupos.containsKey(t.id)) t.id,
      if (grupos.containsKey(null)) null,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(finca?.nombre ?? 'Finca')),
      body: finca == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.only(
                bottom: 96 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _Resumen(
                  finca: finca,
                  cultivo: cultivo,
                  esAdmin: esAdmin,
                  onEditar: () => _editarFinca(context, ref, finca),
                  onCambiarCultivo:
                      FincasService.sePuedeCambiarCultivo(
                            finca,
                            tieneEntregas: entregas.isNotEmpty,
                          ) &&
                          (ref.watch(cultivosOrganizacionProvider).value ??
                                      const [])
                                  .length >
                              1
                      ? () => _cambiarCultivo(context, ref, finca)
                      : null,
                ),
                _TarjetaVerificacion(
                  temporada: actual,
                  visitas: visitas,
                  onVisita: () => _abrirVisita(context, finca),
                  onCorregir: (v) => _corregirVisita(context, ref, v),
                ),
                SeccionFotos(
                  titulo: 'Fotos de la finca',
                  entidadTipo: 'finca',
                  entidadId: fincaId,
                  tipo: 'finca',
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Text(
                    'Entregas al beneficio',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (entregas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Sin entregas. Toca "Entrega" para registrar una.',
                    ),
                  ),
                for (final id in orden) ...[
                  _EncabezadoTemporada(
                    nombre: id == null ? 'Sin temporada' : nombres[id]!,
                    entregas: grupos[id]!,
                  ),
                  for (final e in grupos[id]!)
                    ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(
                        '${kgLegible(e.kg)} kg · ${cultivo.nombreEstado(e.estado)}',
                      ),
                      subtitle: Text(
                        '${fechaHora(e.fecha)}'
                        '${e.corregida ? ' · corregida' : ''}'
                        '${e.loteCodigo != null ? ' · en lote ${e.loteCodigo}' : ''}',
                      ),
                      onTap: () => _corregirEntrega(context, ref, finca, e),
                      trailing: Icon(
                        e.sincronizado ? Icons.cloud_done : Icons.cloud_upload,
                        color: e.sincronizado ? Colors.green : Colors.orange,
                      ),
                    ),
                ],
              ],
            ),
      floatingActionButton: finca == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _nuevaEntrega(context, ref, finca),
              icon: const Icon(Icons.add),
              label: const Text('Entrega'),
            ),
    );
  }
}

String _dos(int n) => n.toString().padLeft(2, '0');
String fecha(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year}';
String fechaHora(DateTime f) => '${fecha(f)} ${_dos(f.hour)}:${_dos(f.minute)}';

class _EncabezadoTemporada extends StatelessWidget {
  const _EncabezadoTemporada({required this.nombre, required this.entregas});

  final String nombre;
  final List<Entrega> entregas;

  @override
  Widget build(BuildContext context) {
    final kg = entregas.fold<double>(0, (s, e) => s + e.kg);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$nombre · ${entregas.length} ${entregas.length == 1 ? 'entrega' : 'entregas'} · '
        '${kgLegible(kg)} kg',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Resumen extends ConsumerWidget {
  const _Resumen({
    required this.finca,
    required this.cultivo,
    required this.esAdmin,
    required this.onEditar,
    this.onCambiarCultivo,
  });

  final Finca finca;
  final Cultivo cultivo;
  final bool esAdmin;

  /// Corregir nombre y, en fincas de un punto, el área declarada.
  final VoidCallback onEditar;

  /// `null` si el cultivo ya no se puede cambiar (tiene entregas) o la
  /// organización trabaja un solo cultivo.
  final VoidCallback? onCambiarCultivo;

  Future<void> _revisarAhora(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(apiProvider).chequearFinca(finca.id);
      await ref.read(syncServiceProvider).sincronizar();
      mensajero.showSnackBar(
        SnackBar(content: Text('Revisión satelital: ${r['resultado']}.')),
      );
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo revisar: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oficial = finca.areaOficialHa;
    final sat = estadosSatelitales[finca.deforestacion];
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(cultivo.icono, color: cultivo.colorUi, size: 20),
                const SizedBox(width: 6),
                Text(
                  cultivo.nombre,
                  style: TextStyle(
                    color: cultivo.colorUi,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Corregir nombre o área',
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined),
                ),
                if (onCambiarCultivo != null)
                  TextButton(
                    onPressed: onCambiarCultivo,
                    child: const Text('Cambiar cultivo'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              oficial != null
                  ? '${oficial.toStringAsFixed(2)} ha (área oficial)'
                  : '${finca.areaHa.toStringAsFixed(2)} ha (calculada en el celular)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Lindero versión ${finca.version}'
              '${oficial == null ? ' · el área oficial llega al sincronizar' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  sat?.$2 ?? Icons.satellite_alt_outlined,
                  color: sat?.$1 ?? Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sat == null
                        ? 'Sin revisión satelital todavía'
                        : '${sat.$3}${finca.ultimoChequeo != null ? ' (${fecha(finca.ultimoChequeo!)})' : ''}',
                  ),
                ),
              ],
            ),
            if (esAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: finca.sincronizado
                      ? () => _revisarAhora(context, ref)
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Revisar por satélite'),
                ),
              ),
            if (finca.attestationUid != null)
              const Text('Registrada en la blockchain ✓'),
          ],
        ),
      ),
    );
  }
}

class _TarjetaVerificacion extends StatelessWidget {
  const _TarjetaVerificacion({
    required this.temporada,
    required this.visitas,
    required this.onVisita,
    required this.onCorregir,
  });

  final Temporada? temporada;
  final List<Verificacion> visitas;
  final VoidCallback onVisita;

  /// Corregir la nota o la fecha de una visita, o anularla.
  final void Function(Verificacion) onCorregir;

  @override
  Widget build(BuildContext context) {
    final deEsta = temporada == null
        ? null
        : visitas.where((v) => v.temporadaId == temporada!.id).firstOrNull;
    final (color, icono, texto) = switch ((temporada, deEsta)) {
      (null, _) => (
        Colors.grey,
        Icons.event_busy,
        'La organización aún no creó la temporada actual.',
      ),
      (_, null) => (
        Colors.orange,
        Icons.pending_actions,
        'Visita de ${temporada!.nombre}: pendiente',
      ),
      (_, final v?) => (
        Colors.green,
        Icons.verified,
        'Visita de ${temporada!.nombre}: hecha el ${fecha(v.fecha)}'
            '${v.linderoCambio ? ' (lindero actualizado)' : ''}',
      ),
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(texto)),
                if (deEsta != null)
                  IconButton(
                    tooltip: 'Corregir visita',
                    onPressed: () => onCorregir(deEsta),
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            if (visitas.length > (deEsta == null ? 0 : 1))
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Visitas anteriores:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final v in visitas.where((v) => v != deEsta))
                      ActionChip(
                        label: Text(fecha(v.fecha)),
                        onPressed: () => onCorregir(v),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onVisita,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  deEsta == null
                      ? 'Hacer visita de verificación'
                      : 'Otra visita',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corregir nombre y, en fincas de un punto, el área declarada. Devuelve
/// (nombre, área o `null` si no cambió, motivo).
class _DialogoFinca extends StatefulWidget {
  const _DialogoFinca({required this.finca, required this.esPunto});

  final Finca finca;
  final bool esPunto;

  @override
  State<_DialogoFinca> createState() => _DialogoFincaState();
}

class _DialogoFincaState extends State<_DialogoFinca> {
  late final _nombre = TextEditingController(text: widget.finca.nombre);
  late final _area = TextEditingController(
    text: widget.finca.areaHa.toString(),
  );
  final _motivo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _area, _motivo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    final area = double.tryParse(_area.text.trim().replaceAll(',', '.'));
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre de la finca.');
      return;
    }
    final cambiaArea = widget.esPunto && area != widget.finca.areaHa;
    if (cambiaArea) {
      if (area == null || area <= 0) {
        setState(() => _error = 'Escribe el área en hectáreas.');
        return;
      }
      if (area >= 4) {
        setState(
          () => _error = 'Una finca de 4 ha o más necesita polígono: marca el lindero en una visita.',
        );
        return;
      }
      if (widget.finca.sincronizado && _motivo.text.trim().length < 3) {
        setState(() => _error = 'Escribe por qué corriges el área.');
        return;
      }
    }
    Navigator.pop(context, (
      nombre,
      cambiaArea ? area : null,
      _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corregir finca'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre de la finca',
              ),
            ),
            if (widget.esPunto) ...[
              TextField(
                controller: _area,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Área declarada',
                  suffixText: 'ha',
                ),
              ),
              if (widget.finca.sincronizado)
                TextField(
                  controller: _motivo,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (si cambias el área)',
                  ),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'El área de un polígono sale del lindero: para corregirla, '
                  'marca un lindero nuevo en una visita de verificación.',
                  style: Theme.of(context).textTheme.bodySmall,
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

/// Resultado del diálogo de visita: corregir (nota, fecha, motivo) o anular.
class _AccionVisita {
  _AccionVisita({this.nota, this.fecha, this.motivo, this.anular});
  final String? nota;
  final DateTime? fecha;
  final String? motivo;

  /// Motivo de la anulación; `null` si es una corrección.
  final String? anular;
}

class _DialogoVisita extends StatefulWidget {
  const _DialogoVisita({required this.visita});

  final Verificacion visita;

  @override
  State<_DialogoVisita> createState() => _DialogoVisitaState();
}

class _DialogoVisitaState extends State<_DialogoVisita> {
  late final _nota = TextEditingController(text: widget.visita.nota ?? '');
  final _motivo = TextEditingController();
  late DateTime _fecha = widget.visita.fecha;
  String? _error;

  @override
  void dispose() {
    _nota.dispose();
    _motivo.dispose();
    super.dispose();
  }

  bool get _cambiaFecha => _fecha != widget.visita.fecha;

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
    );
    if (dia != null) {
      setState(
        () => _fecha = DateTime(
          dia.year,
          dia.month,
          dia.day,
          _fecha.hour,
          _fecha.minute,
        ),
      );
    }
  }

  void _guardar() {
    if (_cambiaFecha &&
        widget.visita.sincronizado &&
        _motivo.text.trim().length < 3) {
      setState(() => _error = 'Escribe por qué cambias la fecha.');
      return;
    }
    final nota = _nota.text.trim();
    Navigator.pop(
      context,
      _AccionVisita(
        nota: nota.isEmpty ? null : nota,
        fecha: _cambiaFecha ? _fecha : null,
        motivo: _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
      ),
    );
  }

  Future<void> _anular() async {
    final motivo = await pedirMotivo(
      context,
      titulo: 'Anular visita',
      explicacion:
          'La finca deja de contar como verificada por esta visita. '
          'Queda en el historial con el motivo.',
      accion: 'Anular',
    );
    if (motivo != null && mounted) {
      Navigator.pop(context, _AccionVisita(anular: motivo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lindero = widget.visita.linderoCambio;
    return AlertDialog(
      title: const Text('Corregir visita'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(fecha(_fecha)),
              subtitle: Text(
                lindero
                    ? 'Registró un lindero nuevo: la fecha no se cambia.'
                    : 'Fecha de la visita',
              ),
              onTap: lindero ? null : _elegirFecha,
            ),
            TextField(
              controller: _nota,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Nota'),
            ),
            if (_cambiaFecha && widget.visita.sincronizado)
              TextField(
                controller: _motivo,
                decoration: const InputDecoration(
                  labelText: 'Motivo del cambio de fecha',
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
            if (!lindero)
              TextButton.icon(
                onPressed: _anular,
                icon: const Icon(Icons.block, color: Colors.red),
                label: const Text(
                  'Anular visita',
                  style: TextStyle(color: Colors.red),
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
