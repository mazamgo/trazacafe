import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/api_client.dart';
import '../widgets/en_linea.dart';
import '../widgets/estado_satelital.dart';
import '../widgets/mapa_fincas.dart';
import 'finca_screen.dart' show fecha;
import 'lotes_screen.dart' show kgTexto;

/// Exportadora: sus compradores (importadores de la UE). Los invita por
/// correo y les asigna contenedores cerrados en Contenedores.
class CompradoresScreen extends ConsumerWidget {
  const CompradoresScreen({super.key});

  Future<void> _invitar(BuildContext context, WidgetRef ref) async {
    final email = await pedirTexto(
      context,
      titulo: 'Invitar comprador',
      etiqueta: 'Correo del administrador del importador',
      accion: 'Invitar',
      explicacion:
          'El importador debe estar dado de alta en TrazaCafé y haber entrado al panel web. '
          'Verá solo los contenedores que le asignes, sin nombres de productores.',
    );
    if (email == null || !context.mounted) return;
    final hecho = await ejecutarEnLinea(
      context,
      () => ref.read(apiProvider).invitarComprador(email),
      'Invitación enviada a $email.',
    );
    if (hecho) ref.invalidate(compradoresProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Compradores')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _invitar(context, ref),
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Invitar comprador'),
    ),
    body: ref
        .watch(compradoresProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorEnLinea(
            'No se pudieron cargar: $e',
            onReintentar: () => ref.invalidate(compradoresProvider),
          ),
          data: (lista) => lista.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Invita a tu comprador para que vea sus contenedores, baje su '
                      'paquete EUDR y reciba alertas satelitales.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  children: [
                    for (final c in lista)
                      ListTile(
                        leading: Icon(
                          c.activo ? Icons.storefront : Icons.hourglass_empty,
                        ),
                        title: Text(c.organizacion),
                        subtitle: Text(
                          c.pendiente
                              ? 'Invitación pendiente'
                              : c.activo
                              ? '${c.contenedores} ${c.contenedores == 1 ? 'contenedor asignado' : 'contenedores asignados'}'
                              : c.estado == 'rechazado'
                              ? 'Invitación rechazada'
                              : 'Vínculo terminado',
                        ),
                        trailing: c.activo || c.pendiente
                            ? IconButton(
                                tooltip: 'Terminar',
                                icon: const Icon(Icons.link_off),
                                onPressed: () async {
                                  final hecho = await ejecutarEnLinea(
                                    context,
                                    () => ref
                                        .read(apiProvider)
                                        .terminarComprador(c.id),
                                    'Vínculo con ${c.organizacion} terminado.',
                                  );
                                  if (hecho) {
                                    ref.invalidate(compradoresProvider);
                                  }
                                },
                              )
                            : null,
                      ),
                  ],
                ),
        ),
  );
}

/// Importador: sus contenedores comprados y las invitaciones de exportadoras.
class ComprasScreen extends ConsumerWidget {
  const ComprasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitaciones = [
      for (final c
          in ref.watch(compradoresProvider).value ?? const <Comprador>[])
        if (c.pendiente) c,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Contenedores comprados')),
      body: ref
          .watch(comprasProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorEnLinea(
              'No se pudieron cargar: $e',
              onReintentar: () => ref.invalidate(comprasProvider),
            ),
            data: (lista) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final i in invitaciones)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.mail_outline),
                      title: Text('${i.organizacion} te invitó como comprador'),
                      subtitle: const Text(
                        'Verás los contenedores que te asigne, con su paquete EUDR.',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          for (final (aceptar, texto) in const [
                            (false, 'Rechazar'),
                            (true, 'Aceptar'),
                          ])
                            TextButton(
                              onPressed: () async {
                                final hecho = await ejecutarEnLinea(
                                  context,
                                  () => ref
                                      .read(apiProvider)
                                      .responderComprador(i.id, aceptar),
                                  aceptar
                                      ? 'Invitación aceptada.'
                                      : 'Invitación rechazada.',
                                );
                                if (hecho) ref.invalidate(compradoresProvider);
                              },
                              child: Text(texto),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (lista.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no tienes contenedores. Aparecen cuando la exportadora '
                      'te asigna uno cerrado.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final x in lista)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${x.contenedor ?? x.codigo} · ${kgTexto(x.kg)} kg',
                      ),
                      subtitle: Text(
                        [
                          '${x.exportadora} · ${x.destino}',
                          '${x.fincasVerdes} de ${x.fincas} fincas en verde'
                              '${x.alertas > 0 ? ' · ${x.alertas} ${x.alertas == 1 ? 'alerta' : 'alertas'}' : ''}',
                          x.ddsRef == null
                              ? 'Sin DDS anotada'
                              : 'DDS: ${x.ddsRef}',
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                      trailing: Icon(
                        x.alertas > 0
                            ? Icons.warning_amber_rounded
                            : Icons.chevron_right,
                        color: x.alertas > 0 ? Colors.orange : null,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CompraScreen(contenedor: x),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

/// Detalle de un contenedor comprado: mapa, fincas, paquete EUDR y DDS.
class CompraScreen extends ConsumerWidget {
  const CompraScreen({super.key, required this.contenedor});

  final ContenedorComprado contenedor;

  Future<void> _bajar(BuildContext context, WidgetRef ref, bool pdf) async {
    final x = contenedor;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(apiProvider);
      final bytes = pdf
          ? await api.pdfComprado(x.id)
          : await api.geojsonComprado(x.id);
      await ref
          .read(compartidorProvider)
          .compartir(
            nombre: pdf
                ? 'Paquete-EUDR-${x.codigo}.pdf'
                : '${x.codigo}.geojson',
            bytes: bytes,
            tipo: pdf ? 'application/pdf' : 'application/geo+json',
            asunto: 'Paquete EUDR ${x.codigo}',
          );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo descargar: $e')),
      );
    }
  }

  Future<void> _dds(BuildContext context, WidgetRef ref) async {
    final ref0 = await pedirTexto(
      context,
      titulo: 'Referencia de tu DDS',
      etiqueta: 'Número de referencia en TRACES',
      accion: 'Guardar',
      minimo: 1,
    );
    if (ref0 == null || !context.mounted) return;
    final hecho = await ejecutarEnLinea(
      context,
      () => ref.read(apiProvider).anotarDds(contenedor.id, ref0),
      'DDS anotada. También la ve la exportadora.',
    );
    if (hecho) ref.invalidate(comprasProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x = contenedor;
    return Scaffold(
      appBar: AppBar(title: Text(x.contenedor ?? x.codigo)),
      body: ref
          .watch(fincasCompradasProvider(x.id))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorEnLinea(
              'No se pudo cargar: $e',
              onReintentar: () => ref.invalidate(fincasCompradasProvider(x.id)),
            ),
            data: (fincas) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  '${x.exportadora} · ${x.codigo} · ${kgTexto(x.kg)} kg · ${x.destino}',
                ),
                Text(x.ddsRef == null ? 'Sin DDS anotada' : 'DDS: ${x.ddsRef}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _bajar(context, ref, true),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _bajar(context, ref, false),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('GeoJSON (TRACES)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _dds(context, ref),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Anotar DDS'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MapaFincas(
                  fincas: [
                    for (final f in fincas)
                      (
                        nombre: f.nombre,
                        puntos: f.puntos,
                        deforestacion: f.deforestacion,
                      ),
                  ],
                ),
                for (final f in fincas)
                  ListTile(
                    leading: Icon(
                      estadosSatelitales[f.deforestacion]?.$2 ??
                          Icons.help_outline,
                      color: estadosSatelitales[f.deforestacion]?.$1,
                    ),
                    title: Text(f.nombre),
                    subtitle: Text(
                      [
                        ?f.proveedor,
                        '${f.areaOficialHa.toStringAsFixed(2)} ha',
                        if (f.ultimoChequeo case final c?)
                          'chequeo del ${fecha(c)}',
                      ].join(' · '),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

/// Importador: alertas satelitales de sus contenedores después de la compra.
class AlertasCompradorScreen extends ConsumerWidget {
  const AlertasCompradorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Alertas')),
    body: ref
        .watch(alertasCompradorProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorEnLinea(
            'No se pudieron cargar: $e',
            onReintentar: () => ref.invalidate(alertasCompradorProvider),
          ),
          data: (lista) => lista.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Sin alertas. Las fincas de origen de tus contenedores se siguen '
                      'revisando por satélite; si una pasa a amarillo o rojo, aparece aquí '
                      'y te avisamos por correo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  children: [
                    for (final a in lista)
                      ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: a.resultado == 'rojo'
                              ? Colors.red
                              : Colors.orange,
                        ),
                        title: Text('${a.finca} · ${a.resultado}'),
                        subtitle: Text(
                          '${a.contenedor} (${a.codigo}) · ${fecha(a.detectadaEn)}',
                        ),
                      ),
                  ],
                ),
        ),
  );
}
