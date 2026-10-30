import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/api_client.dart';
import '../widgets/en_linea.dart';
import '../widgets/estado_satelital.dart';
import '../widgets/mapa_fincas.dart';
import 'finca_screen.dart' show fecha;
import 'lotes_screen.dart' show kgTexto;

/// Exportadora: lo que una cooperativa le vendió, de solo lectura. La
/// exportadora no corrige datos de la cooperativa: deja observaciones.
class RevisionProveedorScreen extends ConsumerWidget {
  const RevisionProveedorScreen({super.key, required this.vinculo});

  final Vinculo vinculo;

  Future<void> _observar(
    BuildContext context,
    WidgetRef ref, {
    String? fincaId,
    String? loteId,
    required String sobre,
  }) async {
    final texto = await pedirTexto(
      context,
      titulo: 'Observación sobre $sobre',
      etiqueta: 'Observación',
      accion: 'Enviar',
      explicacion:
          '${vinculo.organizacion} la ve en su app y la responde. '
          'Por ejemplo: "revisar el lindero norte".',
    );
    if (texto == null || !context.mounted) return;
    if (await ejecutarEnLinea(
      context,
      () => ref
          .read(apiProvider)
          .observar(fincaId: fincaId, loteId: loteId, texto: texto),
      'Observación enviada a ${vinculo.organizacion}.',
    )) {
      ref.invalidate(observacionesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revision = ref.watch(revisionProveedorProvider(vinculo.id));
    return Scaffold(
      appBar: AppBar(title: Text(vinculo.organizacion)),
      body: revision.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorEnLinea(
          'No se pudo cargar la revisión: $e',
          onReintentar: () =>
              ref.invalidate(revisionProveedorProvider(vinculo.id)),
        ),
        data: (r) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(revisionProveedorProvider(vinculo.id).future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _Resumen(r),
              if (r.fincas.isNotEmpty) ...[
                const SizedBox(height: 12),
                MapaFincas(
                  fincas: [
                    for (final f in r.fincas)
                      (
                        nombre: f.nombre,
                        puntos: f.puntos,
                        deforestacion: f.deforestacion,
                      ),
                  ],
                ),
              ],
              const _Titulo('Lotes'),
              if (r.lotes.isEmpty)
                const Text('Todavía no te ha vendido lotes.'),
              for (final l in r.lotes)
                Card(
                  child: ListTile(
                    title: Text(
                      '${l.codigo} · ${kgTexto(l.kgRecibidos ?? l.kgEnviados)} kg',
                    ),
                    subtitle: Text(
                      [
                        '${l.temporadaNombre} · ${l.recibido ? 'recibido' : 'por recibir'}',
                        if (l.attestationUid != null)
                          'Firmado en la blockchain ✓',
                        for (final a in l.avisos) '⚠ ${a.mensaje}',
                      ].join('\n'),
                    ),
                    isThreeLine: l.avisos.isNotEmpty,
                    trailing: IconButton(
                      tooltip: 'Observación',
                      icon: const Icon(Icons.rate_review_outlined),
                      onPressed: () => _observar(
                        context,
                        ref,
                        loteId: l.id,
                        sobre: 'el lote ${l.codigo}',
                      ),
                    ),
                  ),
                ),
              const _Titulo('Fincas de origen'),
              for (final f in r.fincas)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                f.nombre,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Observación',
                              icon: const Icon(Icons.rate_review_outlined),
                              onPressed: () => _observar(
                                context,
                                ref,
                                fincaId: f.id,
                                sobre: f.nombre,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          [
                            ?f.productorNombre,
                            ?f.comunidad,
                            '${f.areaOficialHa.toStringAsFixed(2)} ha '
                                '(${f.puntos.length == 1 ? 'punto' : 'polígono'})',
                          ].join(' · '),
                        ),
                        const SizedBox(height: 6),
                        EstadoSatelital(f.deforestacion),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              f.conVisita
                                  ? Icons.verified
                                  : Icons.pending_actions,
                              size: 18,
                              color: f.conVisita ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                f.conVisita
                                    ? 'Visita de verificación en la temporada'
                                          '${f.ultimaVisita != null ? ' (${fecha(f.ultimaVisita!)})' : ''}'
                                    : 'Sin visita de verificación en la temporada',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lotes: ${f.lotes.join(', ')}'
                          '${f.attestationUid != null ? ' · lindero en la blockchain ✓' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              if (!r.vinculo.comparteNombres)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${vinculo.organizacion} no comparte los nombres de fincas y productores '
                    '(Ley 787): cada finca se identifica con un código.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen(this.r);
  final RevisionProveedor r;

  @override
  Widget build(BuildContext context) {
    final total = r.fincas.length;
    String de(int n) => total == 0 ? '—' : '$n de $total';
    Widget fila(IconData icono, Color? color, String texto) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(texto)),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$total ${total == 1 ? 'finca' : 'fincas'} de origen · '
              '${r.areaOficialHa.toStringAsFixed(2)} ha oficiales',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            fila(
              Icons.check_circle,
              r.verdes == total ? Colors.green : Colors.orange,
              'En verde por satélite: ${de(r.verdes)}',
            ),
            fila(
              Icons.verified,
              r.conVisita == total ? Colors.green : Colors.orange,
              'Con visita en la temporada: ${de(r.conVisita)}',
            ),
            fila(
              Icons.warning_amber_rounded,
              Colors.orange,
              '${r.lotes.fold(0, (s, l) => s + l.avisos.length)} avisos en los lotes',
            ),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
    child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
  );
}
