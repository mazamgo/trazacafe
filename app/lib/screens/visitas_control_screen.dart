import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/control.dart';
import '../widgets/en_linea.dart';
import '../widgets/mapa_fincas.dart';
import 'finca_screen.dart' show fecha;

/// Exportadora (técnicos y administradores): fincas de sus proveedores
/// elegidas para visita de control. La lista y las visitas se guardan en el
/// celular, así que funciona sin señal; las visitas se envían al volver.
class VisitasControlScreen extends ConsumerWidget {
  const VisitasControlScreen({super.key});

  Future<void> _registrar(
    BuildContext context,
    WidgetRef ref,
    FincaControl f,
  ) async {
    final datos = await showDialog<(bool, String?)>(
      context: context,
      builder: (_) => _DialogoVisita(finca: f),
    );
    if (datos == null || !context.mounted) return;
    await ref
        .read(controlServiceProvider)
        .registrar(fincaId: f.id, linderoCambio: !datos.$1, nota: datos.$2);
    ref.invalidate(controlProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Visita de ${f.nombre} guardada.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Visitas de control')),
    body: ref
        .watch(controlProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorEnLinea(
            'No se pudo cargar: $e',
            onReintentar: () => ref.invalidate(controlProvider),
          ),
          data: (c) {
            final enCola = {for (final p in c.pendientes) p['fincaId']};
            return RefreshIndicator(
              onRefresh: () => ref.refresh(controlProvider.future),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (c.sinSenal)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.cloud_off),
                        title: Text('Sin señal: es la lista guardada'),
                        subtitle: Text(
                          'Las visitas se guardan en el celular y se envían solas al volver la señal.',
                        ),
                      ),
                    ),
                  if (c.pendientes.isNotEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.schedule_send_outlined),
                        title: Text(
                          '${c.pendientes.length} '
                          '${c.pendientes.length == 1 ? 'visita sin enviar' : 'visitas sin enviar'}',
                        ),
                        trailing: TextButton(
                          onPressed: () => ref.invalidate(controlProvider),
                          child: const Text('Enviar'),
                        ),
                      ),
                    ),
                  if (c.fincas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay fincas por visitar. El administrador las elige en '
                        'Proveedores → (la cooperativa) → Visitas de control, si la '
                        'cooperativa lo permite.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final f in c.fincas)
                    Card(
                      child: ExpansionTile(
                        leading: Icon(
                          f.visitada
                              ? Icons.check_circle
                              : enCola.contains(f.id)
                              ? Icons.schedule
                              : Icons.radio_button_unchecked,
                          color: f.visitada ? Colors.green : null,
                        ),
                        title: Text('${f.nombre} · ${f.proveedor}'),
                        subtitle: Text(
                          [
                            ?f.productorNombre,
                            ?f.comunidad,
                            '${f.areaOficialHa.toStringAsFixed(2)} ha',
                            f.temporadaNombre,
                            f.visitada
                                ? 'visitada'
                                : enCola.contains(f.id)
                                ? 'visita sin enviar'
                                : 'por visitar',
                          ].join(' · '),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        children: [
                          MapaFincas(
                            alto: 220,
                            fincas: [
                              (
                                nombre: f.nombre,
                                puntos: f.puntos,
                                deforestacion: 'verde',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () => _registrar(context, ref, f),
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Registrar visita'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
  );
}

/// Pregunta si el lindero coincide y una nota. Devuelve (coincide, nota).
class _DialogoVisita extends StatefulWidget {
  const _DialogoVisita({required this.finca});

  final FincaControl finca;

  @override
  State<_DialogoVisita> createState() => _DialogoVisitaState();
}

class _DialogoVisitaState extends State<_DialogoVisita> {
  bool _coincide = true;
  final _nota = TextEditingController();

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Visita de control a ${widget.finca.nombre}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('El lindero coincide con el del mapa'),
          value: _coincide,
          onChanged: (v) => setState(() => _coincide = v),
        ),
        TextField(
          controller: _nota,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            hintText: 'Lo que viste: cultivo, bosque, linderos…',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          _coincide,
          _nota.text.trim().isEmpty ? null : _nota.text.trim(),
        )),
        child: const Text('Guardar'),
      ),
    ],
  );
}

/// Visitas de control ya hechas en un vínculo.
class ControlesScreen extends ConsumerWidget {
  const ControlesScreen({
    super.key,
    required this.vinculoId,
    required this.titulo,
  });

  final String vinculoId;
  final String titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(titulo)),
    body: ref
        .watch(controlesProvider(vinculoId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorEnLinea(
            'No se pudieron cargar: $e',
            onReintentar: () => ref.invalidate(controlesProvider(vinculoId)),
          ),
          data: (lista) => lista.isEmpty
              ? const Center(child: Text('Todavía no hay visitas de control.'))
              : ListView(
                  children: [
                    for (final v in lista)
                      ListTile(
                        leading: Icon(
                          v.linderoCambio
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: v.linderoCambio ? Colors.orange : Colors.green,
                        ),
                        title: Text('${v.finca} · ${fecha(v.fecha)}'),
                        subtitle: Text(
                          [
                            v.linderoCambio
                                ? 'El lindero no coincide'
                                : 'El lindero coincide',
                            ?v.nota,
                            ?v.por,
                          ].join('\n'),
                        ),
                      ),
                  ],
                ),
        ),
  );
}
