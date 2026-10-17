import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../domain/cultivos.dart';
import '../providers.dart';
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
    final entrega = await showModalBottomSheet<EntregasCompanion>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormularioEntrega(
        fincaId: fincaId,
        cultivo: cultivoDe(finca.cultivo),
      ),
    );
    if (entrega == null) return;
    final db = ref.read(databaseProvider);
    final temporada = await db.temporadaDe(
      entrega.fecha.value,
      cultivo: finca.cultivo,
    );
    await db
        .into(db.entregas)
        .insert(entrega.copyWith(temporadaId: Value(temporada?.id)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrega guardada. Se enviará al sincronizar.'),
        ),
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
                _Resumen(finca: finca, cultivo: cultivo, esAdmin: esAdmin),
                _TarjetaVerificacion(
                  temporada: actual,
                  visitas: visitas,
                  onVisita: () => _abrirVisita(context, finca),
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
                        '${_kg(e.kg)} kg · ${cultivo.nombreEstado(e.estado)}',
                      ),
                      subtitle: Text(fechaHora(e.fecha)),
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

  static String _kg(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
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
        '${FincaScreen._kg(kg)} kg',
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
  });

  final Finca finca;
  final Cultivo cultivo;
  final bool esAdmin;

  static const _satelite = {
    'verde': (
      Colors.green,
      Icons.check_circle,
      'Sin deforestación detectada después de 2020',
    ),
    'amarillo': (
      Colors.orange,
      Icons.error,
      'Posible pérdida de bosque pequeña: requiere revisión',
    ),
    'rojo': (
      Colors.red,
      Icons.dangerous,
      'Pérdida de bosque después de 2020: no apta para exportar',
    ),
  };

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
    final sat = _satelite[finca.deforestacion];
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
  });

  final Temporada? temporada;
  final List<Verificacion> visitas;
  final VoidCallback onVisita;

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
              ],
            ),
            if (visitas.length > (deEsta == null ? 0 : 1))
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Text(
                  'Visitas anteriores: ${visitas.where((v) => v != deEsta).map((v) => fecha(v.fecha)).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
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

class _FormularioEntrega extends StatefulWidget {
  const _FormularioEntrega({required this.fincaId, required this.cultivo});

  final String fincaId;
  final Cultivo cultivo;

  @override
  State<_FormularioEntrega> createState() => _FormularioEntregaState();
}

class _FormularioEntregaState extends State<_FormularioEntrega> {
  final _kg = TextEditingController();
  late String _estado = widget.cultivo.estados.first.id;
  DateTime _fecha = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    final elegido = DateTime(
      dia.year,
      dia.month,
      dia.day,
      hora?.hour ?? _fecha.hour,
      hora?.minute ?? _fecha.minute,
    );
    setState(() => _fecha = elegido.isAfter(hoy) ? hoy : elegido);
  }

  void _guardar() {
    final kg = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    if (kg == null || kg <= 0) {
      setState(() => _error = 'Escribe los kilos entregados.');
      return;
    }
    // Mismo límite que la API (cultivos.json).
    final maximo = widget.cultivo.maxKgEntrega;
    if (kg > maximo) {
      setState(
        () => _error =
            'Más de ${_miles(maximo)} kg en una entrega parece un error.',
      );
      return;
    }
    Navigator.pop(
      context,
      EntregasCompanion.insert(
        id: const Uuid().v4(),
        fincaId: widget.fincaId,
        kg: kg,
        estado: _estado,
        fecha: _fecha,
        creadoEn: Value(DateTime.now()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final abajo =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + abajo),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nueva entrega de ${widget.cultivo.nombre.toLowerCase()}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kg,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Kilos entregados',
              suffixText: 'kg',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              for (final e in widget.cultivo.estados)
                ButtonSegment(value: e.id, label: Text(e.corto)),
            ],
            selected: {_estado},
            onSelectionChanged: (s) => setState(() => _estado = s.first),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(fechaHora(_fecha)),
            subtitle: const Text('Fecha de la entrega'),
            onTap: _elegirFecha,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _guardar,
            child: const Text('Guardar entrega'),
          ),
        ],
      ),
    );
  }
}

/// 20000 → "20,000".
String _miles(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
