import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../providers.dart';
import '../widgets/seccion_fotos.dart';

/// Detalle de una finca y sus entregas de café al beneficio.
class FincaScreen extends ConsumerWidget {
  const FincaScreen({super.key, required this.fincaId});

  final String fincaId;

  static const estados = {'uva': 'Uva (café maduro)', 'pergamino': 'Pergamino'};

  Future<void> _nuevaEntrega(BuildContext context, WidgetRef ref) async {
    final entrega = await showModalBottomSheet<EntregasCompanion>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormularioEntrega(fincaId: fincaId),
    );
    if (entrega == null) return;
    final db = ref.read(databaseProvider);
    await db.into(db.entregas).insert(entrega);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrega guardada. Se enviará al sincronizar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finca = ref.watch(fincaProvider(fincaId)).value;
    final entregas = ref.watch(entregasProvider(fincaId));

    return Scaffold(
      appBar: AppBar(title: Text(finca?.nombre ?? 'Finca')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (finca != null) _Resumen(finca: finca),
          SeccionFotos(
            titulo: 'Fotos de la finca',
            entidadTipo: 'finca',
            entidadId: fincaId,
            tipo: 'finca',
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Entregas al beneficio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: entregas.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (lista) => lista.isEmpty
                  ? const Center(
                      child: Text('Sin entregas. Toca + para registrar una.'),
                    )
                  : ListView.separated(
                      itemCount: lista.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = lista[i];
                        return ListTile(
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(
                            '${_kg(e.kg)} kg · ${estados[e.estado] ?? e.estado}',
                          ),
                          subtitle: Text(_fecha(e.fecha)),
                          trailing: Icon(
                            e.sincronizado
                                ? Icons.cloud_done
                                : Icons.cloud_upload,
                            color: e.sincronizado
                                ? Colors.green
                                : Colors.orange,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevaEntrega(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Entrega'),
      ),
    );
  }

  static String _kg(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

  static String _fecha(DateTime f) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.finca});

  final Finca finca;

  @override
  Widget build(BuildContext context) {
    final oficial = finca.areaOficialHa;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              oficial != null
                  ? '${oficial.toStringAsFixed(2)} ha (área oficial)'
                  : '${finca.areaHa.toStringAsFixed(2)} ha (calculada en el celular)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              oficial != null
                  ? 'Calculada por el servidor; es la que va al paquete EUDR.'
                  : 'El área oficial llega al sincronizar.',
            ),
            if (finca.attestationUid != null) ...[
              const SizedBox(height: 4),
              const Text('Registrada en la blockchain ✓'),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormularioEntrega extends StatefulWidget {
  const _FormularioEntrega({required this.fincaId});

  final String fincaId;

  @override
  State<_FormularioEntrega> createState() => _FormularioEntregaState();
}

class _FormularioEntregaState extends State<_FormularioEntrega> {
  final _kg = TextEditingController();
  String _estado = 'uva';
  DateTime _fecha = DateTime.now();
  String? _error;

  /// Mismo límite que la API (backend/src/sync.ts).
  static const _maxKg = 20000;

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
    if (kg > _maxKg) {
      setState(
        () => _error = 'Más de 20,000 kg en una entrega parece un error.',
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
          Text('Nueva entrega', style: Theme.of(context).textTheme.titleLarge),
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
              for (final e in FincaScreen.estados.entries)
                ButtonSegment(
                  value: e.key,
                  label: Text(e.key == 'uva' ? 'Uva' : 'Pergamino'),
                ),
            ],
            selected: {_estado},
            onSelectionChanged: (s) => setState(() => _estado = s.first),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(FincaScreen._fecha(_fecha)),
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
