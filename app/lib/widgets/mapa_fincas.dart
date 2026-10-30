import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers.dart';
import 'capa_sin_senal.dart';
import 'estado_satelital.dart';
import 'mapa_google.dart';

/// Finca a dibujar: un punto (menos de 4 ha) o su polígono, con el color de
/// su chequeo satelital.
typedef FincaEnMapa = ({
  String nombre,
  List<LatLng> puntos,
  String deforestacion,
});

/// Mapa de solo lectura con varias fincas, sobre el satélite de Google (con
/// señal) y los mapas descargados (sin señal), como en "Nueva finca".
class MapaFincas extends ConsumerWidget {
  const MapaFincas({super.key, required this.fincas, this.alto = 280});

  final List<FincaEnMapa> fincas;
  final double alto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesionMapa = ref.watch(sesionMapaProvider).value;
    final descargados = ref.watch(mapasDescargadosProvider).value ?? const [];
    final todos = [for (final f in fincas) ...f.puntos];
    if (todos.isEmpty) return const SizedBox.shrink();
    Color color(String d) => estadosSatelitales[d]?.$1 ?? Colors.grey;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: alto,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: todos.first,
            initialZoom: 15,
            initialCameraFit: todos.length < 2
                ? null
                : CameraFit.coordinates(
                    coordinates: todos,
                    padding: const EdgeInsets.all(32),
                    maxZoom: 17,
                  ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            for (final m in descargados) CapaSinSenal(m, key: ValueKey(m.ruta)),
            if (sesionMapa != null) capaGoogle(sesionMapa),
            PolygonLayer(
              polygons: [
                for (final f in fincas)
                  if (f.puntos.length >= 3)
                    Polygon(
                      points: f.puntos,
                      color: color(f.deforestacion).withValues(alpha: 0.2),
                      borderColor: color(f.deforestacion),
                      borderStrokeWidth: 2,
                    ),
              ],
            ),
            CircleLayer(
              circles: [
                for (final f in fincas)
                  if (f.puntos.length == 1)
                    CircleMarker(
                      point: f.puntos.single,
                      radius: 7,
                      color: color(f.deforestacion),
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final f in fincas)
                  if (f.puntos.isNotEmpty)
                    Marker(
                      point: _centro(f.puntos),
                      width: 140,
                      height: 22,
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        f.nombre,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 3)],
                        ),
                      ),
                    ),
              ],
            ),
            if (sesionMapa != null)
              AtribucionGoogle(
                sesion: sesionMapa,
                servicio: ref.read(mapasServiceProvider),
              ),
            if (descargados.isNotEmpty) AtribucionSinSenal(descargados),
          ],
        ),
      ),
    );
  }

  static LatLng _centro(List<LatLng> p) => LatLng(
    p.map((x) => x.latitude).reduce((a, b) => a + b) / p.length,
    p.map((x) => x.longitude).reduce((a, b) => a + b) / p.length,
  );
}
