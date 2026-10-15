import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../domain/geo.dart';
import '../providers.dart';

/// Registro de una finca: el técnico marca los vértices tocando el mapa o
/// caminando el lindero con "Agregar mi ubicación".
class NuevaFincaScreen extends ConsumerStatefulWidget {
  const NuevaFincaScreen({super.key});

  @override
  ConsumerState<NuevaFincaScreen> createState() => _NuevaFincaScreenState();
}

class _NuevaFincaScreenState extends ConsumerState<NuevaFincaScreen> {
  // Centro inicial: Jinotega.
  static const _centroInicial = LatLng(13.0910, -86.0023);

  final _productorCtrl = TextEditingController();
  final _fincaCtrl = TextEditingController();
  final _mapCtrl = MapController();
  final _puntos = <LatLng>[];
  bool _consentimiento = false;
  bool _guardando = false;

  final _areaDeclaradaCtrl = TextEditingController();

  /// Con polígono el área se calcula; con un solo punto se usa la declarada.
  double get _area => _puntos.length >= 3
      ? areaHectareas(_puntos)
      : double.tryParse(_areaDeclaradaCtrl.text.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _productorCtrl.dispose();
    _fincaCtrl.dispose();
    _areaDeclaradaCtrl.dispose();
    super.dispose();
  }

  Future<void> _agregarMiUbicacion() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      _aviso('Sin permiso de ubicación.');
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    final punto = LatLng(pos.latitude, pos.longitude);
    setState(() => _puntos.add(punto));
    _mapCtrl.move(punto, 17);
  }

  Future<void> _guardar() async {
    if (_productorCtrl.text.trim().isEmpty || _fincaCtrl.text.trim().isEmpty) {
      _aviso('Escribe el nombre del productor y de la finca.');
      return;
    }
    if (!_consentimiento) {
      _aviso('Falta el consentimiento firmado del productor (Ley 787).');
      return;
    }
    if (_puntos.isEmpty || _puntos.length == 2) {
      _aviso('Marca 1 punto (finca < 4 ha) o al menos 3 para el polígono.');
      return;
    }
    final area = _area;
    if (area <= 0) {
      _aviso('Escribe el área declarada de la finca en hectáreas.');
      return;
    }
    if (_puntos.length == 1 && requierePoligono(area)) {
      _aviso('Fincas de 4 ha o más necesitan polígono completo.');
      return;
    }

    setState(() => _guardando = true);
    final db = ref.read(databaseProvider);
    const uuid = Uuid();
    final productorId = uuid.v4();

    await db.transaction(() async {
      await db.into(db.productores).insert(ProductoresCompanion.insert(
            id: productorId,
            nombre: _productorCtrl.text.trim(),
            consentimientoFirmado: const Value(true),
          ));
      await db.into(db.fincas).insert(FincasCompanion.insert(
            id: uuid.v4(),
            productorId: productorId,
            nombre: _fincaCtrl.text.trim(),
            coordenadasJson: aGeoJsonCoords(_puntos),
            areaHa: area,
            geoHash: geoHash(_puntos),
          ));
    });

    if (mounted) Navigator.of(context).pop();
  }

  void _aviso(String texto) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    final esPoligono = _puntos.length >= 3;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva finca')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              TextField(
                controller: _productorCtrl,
                decoration: const InputDecoration(labelText: 'Productor'),
              ),
              TextField(
                controller: _fincaCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de la finca'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consentimiento,
                onChanged: (v) => setState(() => _consentimiento = v ?? false),
                title: const Text('El productor firmó el consentimiento de datos'),
              ),
            ]),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _centroInicial,
                initialZoom: 14,
                onTap: (_, punto) => setState(() => _puntos.add(punto)),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nicarobotica.trazacafe',
                ),
                if (esPoligono)
                  PolygonLayer(polygons: [
                    Polygon(
                      points: _puntos,
                      color: Colors.green.withValues(alpha: 0.3),
                      borderColor: Colors.green.shade800,
                      borderStrokeWidth: 2,
                    ),
                  ]),
                MarkerLayer(
                  markers: [
                    for (final p in _puntos)
                      Marker(
                        point: p,
                        width: 14,
                        height: 14,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.brown,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (esPoligono)
                Text('Área: ${_area.toStringAsFixed(2)} ha')
              else
                TextField(
                  controller: _areaDeclaradaCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Área declarada (ha)',
                    helperText: 'Puntos: ${_puntos.length}. Un solo punto '
                        'solo se permite si la finca mide menos de 4 ha.',
                  ),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _agregarMiUbicacion,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Agregar mi ubicación'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar último punto',
                  onPressed: _puntos.isEmpty
                      ? null
                      : () => setState(_puntos.removeLast),
                  icon: const Icon(Icons.undo),
                ),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: const Text('Guardar finca'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
