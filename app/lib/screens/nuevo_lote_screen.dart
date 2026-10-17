import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/api_client.dart';
import 'finca_screen.dart' show fecha;
import 'lotes_screen.dart' show kgTexto;

/// Arma un lote con entregas de un cultivo y temporada. Devuelve el [Lote]
/// creado con `Navigator.pop`. Las reglas (finca verificada, sin
/// deforestación, entrega libre) las aplica la API; aquí solo se muestran.
class NuevoLoteScreen extends ConsumerStatefulWidget {
  const NuevoLoteScreen({super.key});

  @override
  ConsumerState<NuevoLoteScreen> createState() => _NuevoLoteScreenState();
}

class _NuevoLoteScreenState extends ConsumerState<NuevoLoteScreen> {
  /// Igual que TOLERANCIA_VOLUMEN de la API (backend/src/lotes.ts).
  static const _tolerancia = 0.1;

  String? _cultivo;
  String? _temporadaId;
  String? _estado;
  Future<List<EntregaDisponible>>? _disponibles;
  final _elegidas = <String>{};
  final _codigo = TextEditingController();
  final _kg = TextEditingController();
  final _beneficio = TextEditingController();
  final _proceso = TextEditingController();

  /// Mientras la persona no escriba el peso, se propone el esperado.
  bool _kgEditado = false;
  bool _guardando = false;

  @override
  void dispose() {
    _codigo.dispose();
    _kg.dispose();
    _beneficio.dispose();
    _proceso.dispose();
    super.dispose();
  }

  List<Temporada> _temporadasDe(String cultivo) => [
    for (final t in ref.read(temporadasProvider).value ?? const <Temporada>[])
      if (t.cultivo == null || t.cultivo == cultivo) t,
  ];

  void _elegirCultivo(String? cultivo) {
    final c =
        cultivo ??
        (ref.read(cultivosOrganizacionProvider).value ??
                const [cultivoPorDefecto])
            .first;
    final temporada = temporadaVigente(
      _temporadasDe(c),
      DateTime.now(),
      cultivo: c,
    );
    setState(() {
      _cultivo = c;
      // Por defecto, el estado exportable (café oro, cacao seco).
      _estado = cultivoDe(c).estados
          .firstWhere((e) => e.factorExportable == 1)
          .id;
      _elegirTemporada(temporada?.id ?? _temporadasDe(c).firstOrNull?.id);
    });
  }

  void _elegirTemporada(String? id) {
    _temporadaId = id;
    _elegidas.clear();
    _kgEditado = false;
    _disponibles = id == null
        ? null
        : ref.read(apiProvider).entregasDisponibles(_cultivo!, id);
    _codigo.text = _codigoSugerido();
  }

  /// "CAFE-2026/27-003": cultivo, temporada y número de lote en ella.
  String _codigoSugerido() {
    final t = _temporadasDe(_cultivo!)
        .where((t) => t.id == _temporadaId)
        .firstOrNull;
    if (t == null) return '';
    final prefijo = cultivoDe(_cultivo!).nombre
        .toUpperCase()
        .replaceAll('É', 'E')
        .replaceAll('Á', 'A');
    final hechos = (ref.read(lotesProvider).value ?? const <Lote>[])
        .where((l) => l.cultivo == _cultivo && l.temporadaNombre == t.nombre)
        .length;
    return '$prefijo-${t.nombre}-${(hechos + 1).toString().padLeft(3, '0')}';
  }

  double _esperados(List<EntregaDisponible> entregas) {
    final c = cultivoDe(_cultivo!);
    return entregas
        .where((e) => _elegidas.contains(e.id))
        .fold(0.0, (s, e) => s + c.convertirKg(e.kg, e.estado, _estado!));
  }

  void _actualizarKgPropuesto(List<EntregaDisponible> entregas) {
    if (_kgEditado) return;
    final esperados = _esperados(entregas);
    _kg.text = esperados > 0 ? esperados.round().toString() : '';
  }

  Future<void> _guardar() async {
    final kg = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    final mensajero = ScaffoldMessenger.of(context);
    if (_codigo.text.trim().isEmpty || kg == null || kg <= 0) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('Escribe el código y el peso del lote.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final lote = await ref
          .read(apiProvider)
          .crearLote(
            codigo: _codigo.text.trim(),
            cultivo: _cultivo!,
            temporadaId: _temporadaId!,
            estado: _estado!,
            kg: kg,
            entregas: _elegidas.toList(),
            beneficio: _beneficio.text.trim().isEmpty
                ? null
                : _beneficio.text.trim(),
            proceso: _proceso.text.trim().isEmpty ? null : _proceso.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(lote);
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo crear el lote: $e')),
      );
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cultivosAsync = ref.watch(cultivosOrganizacionProvider);
    final temporadasCargadas = ref.watch(temporadasProvider).hasValue;
    final cultivos = cultivosAsync.value ?? const [cultivoPorDefecto];
    final cultivoId = _cultivo;
    if (cultivoId == null) {
      // Primero tienen que llegar los cultivos y las temporadas de la base
      // local: con ellos se elige la temporada vigente.
      if (cultivosAsync.hasValue && temporadasCargadas) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _cultivo == null) _elegirCultivo(null);
        });
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Nuevo lote')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final c = cultivoDe(cultivoId);
    final temporadas = _temporadasDe(cultivoId);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo lote')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (cultivos.length > 1) ...[
            SegmentedButton<String>(
              segments: [
                for (final x in cultivos.map(cultivoDe))
                  ButtonSegment(
                    value: x.id,
                    icon: Icon(x.icono, color: x.colorUi),
                    label: Text(x.nombre),
                  ),
              ],
              selected: {cultivoId},
              onSelectionChanged: (s) => _elegirCultivo(s.first),
            ),
            const SizedBox(height: 12),
          ],
          if (temporadas.isEmpty)
            const Text(
              'No hay temporadas para este cultivo. Créala en ⋮ → Temporadas.',
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _temporadaId,
              key: ValueKey('temporada-$cultivoId'),
              decoration: const InputDecoration(labelText: 'Temporada'),
              items: [
                for (final t in temporadas)
                  DropdownMenuItem(value: t.id, child: Text(t.nombre)),
              ],
              onChanged: (id) => setState(() => _elegirTemporada(id)),
            ),
          const SizedBox(height: 12),
          Text(
            'El lote queda como:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: [
              for (final e in c.estados)
                ButtonSegment(value: e.id, label: Text(e.corto)),
            ],
            selected: {_estado!},
            onSelectionChanged: (s) => setState(() {
              _estado = s.first;
              _kgEditado = false;
            }),
          ),
          const SizedBox(height: 16),
          if (_disponibles != null)
            FutureBuilder<List<EntregaDisponible>>(
              future: _disponibles,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    'No se pudieron cargar las entregas: ${snap.error}',
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _entregasYDatos(c, snap.data!);
              },
            ),
        ],
      ),
    );
  }

  Widget _entregasYDatos(Cultivo c, List<EntregaDisponible> entregas) {
    final libres = [
      for (final e in entregas)
        if (e.motivo == null) e,
    ];
    final excluidas = [
      for (final e in entregas)
        if (e.motivo != null) e,
    ];
    final esperados = _esperados(entregas);
    final kg = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    final excede =
        kg != null && esperados > 0 && kg > esperados * (1 + _tolerancia);
    final nombreEstado = c.nombreEstado(_estado!).toLowerCase();

    void cambiar(void Function() f) => setState(() {
      f();
      _actualizarKgPropuesto(entregas);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Entregas disponibles (${libres.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (libres.isNotEmpty)
              TextButton(
                onPressed: () => cambiar(() {
                  if (_elegidas.length == libres.length) {
                    _elegidas.clear();
                  } else {
                    _elegidas.addAll(libres.map((e) => e.id));
                  }
                }),
                child: Text(
                  _elegidas.length == libres.length
                      ? 'Quitar todas'
                      : 'Elegir todas',
                ),
              ),
          ],
        ),
        if (libres.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No hay entregas libres en esta temporada.'),
          ),
        for (final e in libres)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _elegidas.contains(e.id),
            onChanged: (v) => cambiar(
              () => v == true ? _elegidas.add(e.id) : _elegidas.remove(e.id),
            ),
            title: Text(
              '${e.fincaNombre} · ${kgTexto(e.kg)} kg ${c.nombreEstado(e.estado).toLowerCase()}',
            ),
            subtitle: Text(
              '${e.productorNombre} · ${fecha(e.fecha)}'
              '${e.deforestacion == 'verde' ? '' : ' · satélite: ${e.deforestacion}'}',
            ),
          ),
        if (excluidas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'No pueden ir en un lote (${excluidas.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final e in excluidas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: false,
              leading: const Icon(Icons.block),
              title: Text('${e.fincaNombre} · ${kgTexto(e.kg)} kg'),
              subtitle: Text(e.motivo!),
            ),
        ],
        const Divider(height: 24),
        Text(
          _elegidas.isEmpty
              ? 'Elige las entregas del lote.'
              : '${_elegidas.length} ${_elegidas.length == 1 ? 'entrega' : 'entregas'}: '
                    'rinden unos ${kgTexto(esperados)} kg de $nombreEstado.',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codigo,
          decoration: const InputDecoration(labelText: 'Código del lote'),
        ),
        TextField(
          controller: _kg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Peso del lote en la báscula',
            suffixText: 'kg',
            helperText: excede
                ? 'Pesa más de lo que rinden sus entregas: se guardará con un aviso.'
                : null,
            helperStyle: const TextStyle(color: Colors.orange),
          ),
          onChanged: (_) => setState(() => _kgEditado = true),
        ),
        TextField(
          controller: _beneficio,
          decoration: const InputDecoration(
            labelText: 'Beneficio o centro de acopio (opcional)',
            helperText:
                'Si lo dejas vacío, se usa el nombre de la organización.',
          ),
        ),
        TextField(
          controller: _proceso,
          decoration: const InputDecoration(
            labelText: 'Proceso (opcional)',
            hintText: 'p. ej. lavado, natural, honey',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _elegidas.isEmpty || _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Crear lote'),
        ),
      ],
    );
  }
}
