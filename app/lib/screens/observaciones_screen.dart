import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/api_client.dart';
import '../widgets/en_linea.dart';
import 'finca_screen.dart' show fecha;

/// Observaciones entre exportadora y cooperativa (solo administradores;
/// requiere señal): las que hizo la exportadora sobre fincas o lotes que le
/// vendieron, y las que la cooperativa recibió y responde.
class ObservacionesScreen extends ConsumerWidget {
  const ObservacionesScreen({super.key});

  Future<void> _responder(
    BuildContext context,
    WidgetRef ref,
    Observacion o,
  ) async {
    final texto = await pedirTexto(
      context,
      titulo: 'Responder a ${o.cliente}',
      etiqueta: 'Respuesta',
      accion: 'Enviar',
      explicacion: '"${o.texto}"',
      minimo: 1,
    );
    if (texto == null || !context.mounted) return;
    if (await ejecutarEnLinea(
      context,
      () => ref.read(apiProvider).responderObservacion(o.id, texto),
      'Respuesta enviada a ${o.cliente}.',
    )) {
      ref.invalidate(observacionesProvider);
      ref.invalidate(avisosRedProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(observacionesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Observaciones')),
      body: lista.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorEnLinea(
          'No se pudieron cargar las observaciones: $e',
          onReintentar: () => ref.invalidate(observacionesProvider),
        ),
        data: (obs) => RefreshIndicator(
          onRefresh: () => ref.refresh(observacionesProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (obs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Sin observaciones. La exportadora las deja desde la revisión de '
                    'un proveedor; la cooperativa las responde aquí.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final o in obs)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${o.sobre} · ${o.hecha ? o.proveedora : o.cliente}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${o.hecha ? 'Hiciste' : '${o.cliente} hizo'} esta observación el ${fecha(o.creadoEn)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(o.texto),
                        const SizedBox(height: 8),
                        if (o.respuesta != null)
                          Text(
                            'Respuesta: ${o.respuesta}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          )
                        else if (o.hecha)
                          const Text(
                            'Sin respuesta todavía',
                            style: TextStyle(color: Colors.orange),
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: () => _responder(context, ref, o),
                              child: const Text('Responder'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
