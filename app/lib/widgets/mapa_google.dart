import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/mapas_service.dart';

/// Capa de mosaicos satelitales de Google para `FlutterMap`.
TileLayer capaGoogle(SesionMapa sesion) => TileLayer(
  urlTemplate: sesion.urlMosaicos,
  userAgentPackageName: 'com.goproduction.trazacafe',
  // Copia modificable: flutter_map le agrega su propio User-Agent, y con
  // el mapa `const` lanzaba "Cannot modify unmodifiable map" (pantalla en
  // blanco en el APK release).
  tileProvider: NetworkTileProvider(headers: {...MapasService.encabezados}),
  maxNativeZoom: 20,
  maxZoom: 21,
);

/// Atribución que exige Google: su nombre y el copyright de las imágenes que
/// están a la vista, que cambia según la zona y el zoom. Va como hijo de
/// `FlutterMap` (después de las capas) para conocer la cámara.
class AtribucionGoogle extends StatefulWidget {
  const AtribucionGoogle({
    super.key,
    required this.sesion,
    required this.servicio,
  });

  final SesionMapa sesion;
  final MapasService servicio;

  @override
  State<AtribucionGoogle> createState() => _AtribucionGoogleState();
}

class _AtribucionGoogleState extends State<AtribucionGoogle> {
  String? _copyright;
  Timer? _espera;
  String? _ultimaVista;

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  /// Pide la atribución un momento después de que el mapa se detiene.
  void _actualizar(MapCamera camara) {
    final b = camara.visibleBounds;
    final vista =
        '${camara.zoom.round()} ${b.north.toStringAsFixed(3)} ${b.west.toStringAsFixed(3)}';
    if (vista == _ultimaVista) return;
    _ultimaVista = vista;
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 800), () async {
      final texto = await widget.servicio.atribucion(
        widget.sesion,
        zoom: camara.zoom.round(),
        norte: b.north,
        sur: b.south,
        este: b.east,
        oeste: b.west,
      );
      if (mounted && texto != null) setState(() => _copyright = texto);
    });
  }

  @override
  Widget build(BuildContext context) {
    _actualizar(MapCamera.of(context));
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: Colors.white.withValues(alpha: 0.8),
        child: Text(
          _copyright == null ? 'Google' : 'Google · $_copyright',
          style: const TextStyle(fontSize: 10, color: Colors.black87),
        ),
      ),
    );
  }
}
