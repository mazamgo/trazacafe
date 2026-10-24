import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/mapas_sin_senal.dart';
import '../services/mbtiles.dart';

/// Capa satelital descargada (Sentinel-2). Va debajo de la de Google: con
/// señal se ve Google; sin señal, Google no carga y queda esta a la vista.
class CapaSinSenal extends StatefulWidget {
  const CapaSinSenal(this.mapa, {super.key});

  final MapaDescargado mapa;

  @override
  State<CapaSinSenal> createState() => _CapaSinSenalState();
}

class _CapaSinSenalState extends State<CapaSinSenal> {
  // `TileLayer` cierra el archivo (dispose del proveedor) al quitar la capa.
  late final _proveedor = MbTilesTileProvider(widget.mapa.ruta);

  @override
  Widget build(BuildContext context) => TileLayer(
    tileProvider: _proveedor,
    userAgentPackageName: 'com.goproduction.trazacafe',
    tileBounds: widget.mapa.paquete.limites,
    // Sentinel-2 tiene 10 m por píxel (zoom 14); más cerca se agranda.
    maxNativeZoom: widget.mapa.paquete.maxZoom,
    maxZoom: 21,
  );
}

/// Crédito que exige Copernicus, cuando hay un mapa descargado en pantalla.
class AtribucionSinSenal extends StatelessWidget {
  const AtribucionSinSenal(this.mapas, {super.key});

  final List<MapaDescargado> mapas;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomLeft,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 22),
      child: Text(
        {for (final m in mapas) m.paquete.atribucion}.join(' · '),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          shadows: [Shadow(blurRadius: 2)],
        ),
      ),
    ),
  );
}
