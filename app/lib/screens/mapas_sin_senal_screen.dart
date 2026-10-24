import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/mapas_sin_senal.dart';

/// Descargar el mapa satelital de una zona para verlo sin señal en "Nueva
/// finca". Las imágenes son Sentinel-2 (10 m por píxel): sirven para ubicarse
/// y ver bosque, claros, caminos y ríos; el lindero se marca con el GPS.
class MapasSinSenalScreen extends ConsumerStatefulWidget {
  const MapasSinSenalScreen({super.key});

  @override
  ConsumerState<MapasSinSenalScreen> createState() =>
      _MapasSinSenalScreenState();
}

class _MapasSinSenalScreenState extends ConsumerState<MapasSinSenalScreen> {
  late Future<List<PaqueteMapa>> _disponibles = ref
      .read(mapasSinSenalProvider)
      .disponibles();

  /// Descargas en curso: id → avance de 0 a 1.
  final _avance = <String, double>{};

  Future<void> _descargar(PaqueteMapa p) async {
    setState(() => _avance[p.id] = 0);
    try {
      await ref
          .read(mapasSinSenalProvider)
          .descargar(
            p,
            avance: (a) {
              if (mounted) setState(() => _avance[p.id] = a);
            },
          );
      ref.invalidate(mapasDescargadosProvider);
      _aviso('Listo: el mapa de ${p.nombre} ya está en el celular.');
    } catch (e) {
      _aviso('No se pudo descargar: $e');
    } finally {
      if (mounted) setState(() => _avance.remove(p.id));
    }
  }

  Future<void> _borrar(MapaDescargado m) async {
    await ref.read(mapasSinSenalProvider).borrar(m.paquete.id);
    ref.invalidate(mapasDescargadosProvider);
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final descargados = ref.watch(mapasDescargadosProvider).value ?? const [];
    final ids = {for (final m in descargados) m.paquete.id};
    final pequeno = Theme.of(context).textTheme.bodySmall;

    return Scaffold(
      appBar: AppBar(title: const Text('Mapas sin señal')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(
            () => _disponibles = ref.read(mapasSinSenalProvider).disponibles(),
          );
          await _disponibles.catchError((_) => <PaqueteMapa>[]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Descarga con Wi-Fi el mapa satelital de tu zona. En la '
                'montaña, sin señal, se ve en "Nueva finca" en lugar del de '
                'Google. Es de menor detalle (10 m): sirve para ubicarte y '
                'ver bosque, claros, caminos y ríos. El lindero se sigue '
                'marcando con el GPS.',
              ),
            ),
            if (descargados.isNotEmpty)
              const ListTile(title: Text('En el celular')),
            for (final m in descargados)
              ListTile(
                leading: const Icon(Icons.offline_pin, color: Colors.green),
                title: Text(m.paquete.nombre),
                subtitle: Text(
                  '${m.paquete.tamano} · imágenes ${m.paquete.imagenes}',
                ),
                trailing: IconButton(
                  tooltip: 'Borrar del celular',
                  onPressed: () => _borrar(m),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            const ListTile(title: Text('Para descargar')),
            FutureBuilder<List<PaqueteMapa>>(
              future: _disponibles,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (s.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Sin señal: la lista de mapas necesita internet. Los '
                      'mapas que ya están en el celular funcionan sin señal.',
                      style: pequeno,
                    ),
                  );
                }
                final pendientes = [
                  for (final p in s.data!)
                    if (!ids.contains(p.id)) p,
                ];
                if (pendientes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Ya tienes todos los mapas disponibles.',
                      style: pequeno,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final p in pendientes)
                      ListTile(
                        leading: const Icon(Icons.satellite_alt),
                        title: Text(p.nombre),
                        subtitle: _avance.containsKey(p.id)
                            ? LinearProgressIndicator(value: _avance[p.id])
                            : Text('${p.tamano} · imágenes ${p.imagenes}'),
                        trailing: FilledButton.tonal(
                          onPressed: _avance.containsKey(p.id)
                              ? null
                              : () => _descargar(p),
                          child: const Text('Descargar'),
                        ),
                      ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Imágenes: Contains modified Copernicus Sentinel data.',
                style: pequeno,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
