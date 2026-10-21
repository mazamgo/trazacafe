import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/cedula.dart';
import '../providers.dart';
import '../services/api_client.dart';
import '../widgets/eliminacion.dart';
import '../widgets/motivo.dart';
import 'finca_screen.dart' show fecha;

/// Productores que pidieron borrar sus datos en la página web (solo
/// administradores). El administrador busca a quién corresponde la
/// solicitud y la aprueba, o la rechaza con el motivo.
class SolicitudesEliminacionScreen extends ConsumerWidget {
  const SolicitudesEliminacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(solicitudesEliminacionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de eliminación')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(solicitudesEliminacionProvider.future),
        child: solicitudes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudieron cargar (necesitas señal): $e'),
              ),
            ],
          ),
          data: (lista) => lista.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay solicitudes pendientes. Cuando un productor pida '
                        'borrar sus datos en la página web, aparecerá aquí.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: EdgeInsets.only(
                    bottom: 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    for (final s in lista) _TarjetaSolicitud(solicitud: s),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TarjetaSolicitud extends ConsumerStatefulWidget {
  const _TarjetaSolicitud({required this.solicitud});

  final SolicitudEliminacion solicitud;

  @override
  ConsumerState<_TarjetaSolicitud> createState() => _TarjetaSolicitudState();
}

class _TarjetaSolicitudState extends ConsumerState<_TarjetaSolicitud> {
  bool _trabajando = false;

  SolicitudEliminacion get s => widget.solicitud;

  Future<void> _aprobar() async {
    final productor = await showDialog<Productor>(
      context: context,
      builder: (_) => _ElegirProductor(solicitud: s),
    );
    if (productor == null || !mounted) return;
    if (!await confirmarEliminacionProductor(context, productor.nombre)) return;
    await _hacer(() async {
      final r = await ref
          .read(eliminacionServiceProvider)
          .aprobarSolicitud(s.id, productor.id);
      return resumenEliminacion(r);
    });
  }

  Future<void> _rechazar() async {
    final motivo = await pedirMotivo(
      context,
      titulo: 'Rechazar la solicitud',
      explicacion:
          'Por ejemplo: no es productor de la cooperativa. Avísale a '
          '${s.nombre} (${s.contacto}) antes de rechazarla: al cerrarla se '
          'borran los datos que escribió.',
      accion: 'Rechazar',
    );
    if (motivo == null) return;
    await _hacer(() async {
      await ref
          .read(eliminacionServiceProvider)
          .rechazarSolicitud(s.id, motivo);
      return 'Solicitud rechazada.';
    });
  }

  Future<void> _hacer(Future<String> Function() accion) async {
    setState(() => _trabajando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final texto = await accion();
      mensajero.showSnackBar(SnackBar(content: Text(texto)));
      ref.invalidate(solicitudesEliminacionProvider);
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dias = DateTime.now().difference(s.creadaEn).inDays;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.nombre, style: Theme.of(context).textTheme.titleMedium),
            Text(
              [
                if (s.cedula != null) 'Cédula ${s.cedula}',
                if (s.comunidad != null) s.comunidad!,
                'Contacto: ${s.contacto}',
              ].join(' · '),
            ),
            if (s.mensaje != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('"${s.mensaje}"'),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Recibida el ${fecha(s.creadaEn)}'
                '${dias >= 15 ? ' · hace $dias días: respóndela pronto' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: dias >= 15
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
            if (_trabajando) const LinearProgressIndicator(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _trabajando ? null : _rechazar,
                  child: const Text('Rechazar'),
                ),
                FilledButton(
                  onPressed: _trabajando ? null : _aprobar,
                  child: const Text('Buscar y eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de productores de la organización para elegir a quién corresponde
/// la solicitud; empieza filtrada por la cédula o el nombre que escribió.
class _ElegirProductor extends ConsumerStatefulWidget {
  const _ElegirProductor({required this.solicitud});

  final SolicitudEliminacion solicitud;

  @override
  ConsumerState<_ElegirProductor> createState() => _ElegirProductorState();
}

class _ElegirProductorState extends ConsumerState<_ElegirProductor> {
  late final _buscar = TextEditingController(
    text: widget.solicitud.cedula ?? widget.solicitud.nombre,
  );

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  static String _normal(String t) => t
      .toLowerCase()
      .replaceAll(RegExp('[áä]'), 'a')
      .replaceAll(RegExp('[éë]'), 'e')
      .replaceAll(RegExp('[íï]'), 'i')
      .replaceAll(RegExp('[óö]'), 'o')
      .replaceAll(RegExp('[úü]'), 'u')
      .replaceAll('-', '')
      .trim();

  @override
  Widget build(BuildContext context) {
    final todos = [
      for (final x in ref.watch(productoresProvider).value ?? const [])
        if (!x.productor.anonimizado) x.productor,
    ];
    final texto = _buscar.text.trim();
    final cedula = normalizarCedula(texto);
    final palabras = _normal(texto)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final lista = texto.isEmpty
        ? todos
        : [
            for (final p in todos)
              if ((cedula != null && p.cedula == cedula) ||
                  palabras.every((w) => _normal(p.nombre).contains(w)))
                p,
          ];
    return AlertDialog(
      title: const Text('¿Quién es?'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _buscar,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Nombre o cédula',
              ),
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: lista.isEmpty
                  ? const Center(
                      child: Text(
                        'Nadie coincide. Prueba con otra parte del nombre; '
                        'si no es de la cooperativa, rechaza la solicitud.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final p in lista)
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(p.nombre),
                            subtitle: Text(
                              [
                                if (p.cedula != null) p.cedula!,
                                if (p.comunidad != null) p.comunidad!,
                              ].join(' · '),
                            ),
                            onTap: () => Navigator.pop(context, p),
                          ),
                      ],
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
      ],
    );
  }
}
