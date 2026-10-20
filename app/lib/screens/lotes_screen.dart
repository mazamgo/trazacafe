import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/api_client.dart';
import 'finca_screen.dart' show fecha;
import 'nuevo_lote_screen.dart';

/// "20000.4" → "20,000".
String kgTexto(double kg) => kg.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+$)'),
  (_) => ',',
);

/// Lotes del beneficio o centro de acopio (solo administradores; requiere
/// señal: se arman con las entregas de todo el equipo, que están en el servidor).
class LotesScreen extends ConsumerWidget {
  const LotesScreen({super.key});

  Future<void> _nuevo(BuildContext context, WidgetRef ref) async {
    final lote = await Navigator.of(context)
        .push<Lote>(MaterialPageRoute(builder: (_) => const NuevoLoteScreen()));
    if (lote == null || !context.mounted) return;
    ref.invalidate(lotesProvider);
    if (lote.avisos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lote ${lote.codigo} creado.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: Text('Lote ${lote.codigo} creado con avisos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in lote.avisos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• ${a.mensaje}'),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _corregir(BuildContext context, WidgetRef ref, Lote l) async {
    final cambios = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _DialogoLote(lote: l),
    );
    if (cambios == null || cambios.isEmpty || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).corregirLote(l.id, cambios);
      ref.invalidate(lotesProvider);
      mensajero.showSnackBar(
        SnackBar(content: Text('Lote ${l.codigo} corregido.')),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo corregir: $e')),
      );
    }
  }

  Future<void> _deshacer(BuildContext context, WidgetRef ref, Lote l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Deshacer el lote ${l.codigo}?'),
        content: const Text(
          'Sus entregas quedan libres para armar otro lote. No se borra ninguna entrega.',
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
      await ref.read(apiProvider).eliminarLote(l.id);
      ref.invalidate(lotesProvider);
      mensajero.showSnackBar(
        SnackBar(content: Text('Lote ${l.codigo} deshecho.')),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo deshacer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotes = ref.watch(lotesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lotes')),
      body: lotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudieron cargar los lotes: $e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(lotesProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (lista) => RefreshIndicator(
          onRefresh: () => ref.refresh(lotesProvider.future),
          child: lista.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no hay lotes. Un lote agrupa entregas de un mismo cultivo y '
                        'temporada que el beneficio procesa juntas. Solo entran entregas de '
                        'fincas con visita de verificación y sin deforestación.',
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
                    for (final l in lista)
                      _TarjetaLote(
                        lote: l,
                        onCorregir: l.atestado || l.exportacionCodigo != null
                            ? null
                            : () => _corregir(context, ref, l),
                        onDeshacer: l.atestado || l.exportacionCodigo != null
                            ? null
                            : () => _deshacer(context, ref, l),
                      ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevo(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Lote'),
      ),
    );
  }
}

class _TarjetaLote extends StatelessWidget {
  const _TarjetaLote({
    required this.lote,
    required this.onDeshacer,
    required this.onCorregir,
  });

  final Lote lote;
  final VoidCallback? onDeshacer;

  /// Peso, código, beneficio o proceso; `null` si ya no se puede.
  final VoidCallback? onCorregir;

  @override
  Widget build(BuildContext context) {
    final c = cultivoDe(lote.cultivo);
    final fincas = {for (final e in lote.entregas) e.fincaNombre}.length;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ExpansionTile(
        leading: Icon(c.icono, color: c.colorUi),
        title: Text('${lote.codigo} · ${kgTexto(lote.kg)} kg'),
        subtitle: Text(
          '${c.nombre} ${c.nombreEstado(lote.estado).toLowerCase()} · ${lote.temporadaNombre} · '
          '${lote.entregas.length} ${lote.entregas.length == 1 ? 'entrega' : 'entregas'}, '
          '$fincas ${fincas == 1 ? 'finca' : 'fincas'}',
        ),
        trailing: lote.avisos.isEmpty
            ? null
            : Badge(
                label: Text('${lote.avisos.length}'),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beneficio: ${lote.beneficio}'
            '${lote.proceso != null ? ' · Proceso: ${lote.proceso}' : ''}',
          ),
          Text(
            'Las entregas rinden unos ${kgTexto(lote.kgEsperados)} kg de '
            '${c.nombreEstado(lote.estado).toLowerCase()} · creado el ${fecha(lote.creadoEn)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final a in lote.avisos)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(a.mensaje)),
                ],
              ),
            ),
          const Divider(height: 20),
          for (final e in lote.entregas)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${e.fincaNombre} (${e.productorNombre}) · ${kgTexto(e.kg)} kg '
                '${c.nombreEstado(e.estado).toLowerCase()} · ${fecha(e.fecha)}',
              ),
            ),
          if (lote.atestado)
            const Text('Registrado en la blockchain ✓')
          else if (lote.exportacionCodigo != null)
            Text('Va en el contenedor ${lote.exportacionCodigo}.')
          else
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDeshacer,
                  icon: const Icon(Icons.undo),
                  label: const Text('Deshacer lote'),
                ),
                TextButton.icon(
                  onPressed: onCorregir,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Corregir'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Corrige peso de báscula, código, beneficio y proceso. Devuelve solo lo
/// que cambió (con motivo si cambia el peso).
class _DialogoLote extends StatefulWidget {
  const _DialogoLote({required this.lote});

  final Lote lote;

  @override
  State<_DialogoLote> createState() => _DialogoLoteState();
}

class _DialogoLoteState extends State<_DialogoLote> {
  late final _kg = TextEditingController(text: widget.lote.kg.toString());
  late final _codigo = TextEditingController(text: widget.lote.codigo);
  late final _beneficio = TextEditingController(text: widget.lote.beneficio);
  late final _proceso = TextEditingController(text: widget.lote.proceso ?? '');
  final _motivo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_kg, _codigo, _beneficio, _proceso, _motivo]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _kgNuevo => double.tryParse(_kg.text.trim().replaceAll(',', '.'));

  void _guardar() {
    final l = widget.lote;
    final kg = _kgNuevo;
    if (kg == null ||
        kg <= 0 ||
        _codigo.text.trim().isEmpty ||
        _beneficio.text.trim().isEmpty) {
      setState(() => _error = 'Revisa el peso, el código y el beneficio.');
      return;
    }
    final motivo = _motivo.text.trim();
    if (kg != l.kg && motivo.length < 3) {
      setState(() => _error = 'Escribe por qué corriges el peso.');
      return;
    }
    final proceso = _proceso.text.trim();
    Navigator.pop(context, <String, Object?>{
      if (kg != l.kg) 'kg': kg,
      if (_codigo.text.trim() != l.codigo) 'codigo': _codigo.text.trim(),
      if (_beneficio.text.trim() != l.beneficio)
        'beneficio': _beneficio.text.trim(),
      if ((proceso.isEmpty ? null : proceso) != l.proceso)
        'proceso': proceso.isEmpty ? null : proceso,
      if (motivo.isNotEmpty) 'motivo': motivo,
    });
  }

  @override
  Widget build(BuildContext context) {
    final kg = _kgNuevo;
    // Mismo umbral que la API (TOLERANCIA_VOLUMEN, 10 %).
    final excede = kg != null && kg > widget.lote.kgEsperados * 1.1;
    return AlertDialog(
      title: Text('Corregir ${widget.lote.codigo}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _kg,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Peso del lote en la báscula',
                suffixText: 'kg',
                helperText: excede
                    ? 'Pesa más de lo que rinden sus entregas '
                          '(unos ${kgTexto(widget.lote.kgEsperados)} kg).'
                    : 'Sus entregas rinden unos ${kgTexto(widget.lote.kgEsperados)} kg.',
                helperStyle: excede
                    ? const TextStyle(color: Colors.orange)
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _motivo,
              decoration: const InputDecoration(
                labelText: 'Motivo (si cambias el peso)',
              ),
            ),
            TextField(
              controller: _codigo,
              decoration: const InputDecoration(labelText: 'Código del lote'),
            ),
            TextField(
              controller: _beneficio,
              decoration: const InputDecoration(
                labelText: 'Beneficio o centro de acopio',
              ),
            ),
            TextField(
              controller: _proceso,
              decoration: const InputDecoration(
                labelText: 'Proceso (opcional)',
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
