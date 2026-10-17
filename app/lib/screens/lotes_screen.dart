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
                        onDeshacer: l.atestado
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
  const _TarjetaLote({required this.lote, required this.onDeshacer});

  final Lote lote;
  final VoidCallback? onDeshacer;

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
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDeshacer,
                icon: const Icon(Icons.undo),
                label: const Text('Deshacer lote'),
              ),
            ),
        ],
      ),
    );
  }
}
