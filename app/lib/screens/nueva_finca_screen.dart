import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../domain/cultivos.dart';
import '../domain/geo.dart';
import '../providers.dart';
import '../services/fotos_service.dart';
import '../widgets/mapa_google.dart';

/// Lindero dibujado en modo "nuevo lindero" (se devuelve, no se guarda aquí).
typedef LinderoNuevo = ({
  String coordenadasJson,
  double areaHa,
  String geoHash,
});

/// Registro de una finca: el técnico marca los vértices tocando el mapa o
/// caminando el lindero con "Agregar mi ubicación".
///
/// Con [linderoAnterior] sirve para volver a dibujar el lindero en una visita
/// de verificación: muestra el anterior como referencia y devuelve el nuevo
/// con `Navigator.pop` como [LinderoNuevo], sin tocar la base.
class NuevaFincaScreen extends ConsumerStatefulWidget {
  const NuevaFincaScreen({super.key, this.productorId, this.linderoAnterior})
    : assert(productorId != null || linderoAnterior != null);

  final String? productorId;
  final List<LatLng>? linderoAnterior;

  bool get esLindero => linderoAnterior != null;

  @override
  ConsumerState<NuevaFincaScreen> createState() => _NuevaFincaScreenState();
}

class _NuevaFincaScreenState extends ConsumerState<NuevaFincaScreen> {
  // Centro inicial: Jinotega.
  static const _centroInicial = LatLng(13.0910, -86.0023);

  final _fincaCtrl = TextEditingController();
  final _mapCtrl = MapController();
  final _puntos = <LatLng>[];
  final _fotos = <FotoTomada>[];
  bool _guardando = false;

  /// Elegido por el técnico; `null` = el primero de la organización.
  String? _cultivoElegido;

  List<String> get _cultivosOrg =>
      ref.read(cultivosOrganizacionProvider).value ?? const [cultivoPorDefecto];

  String get _cultivo => _cultivoElegido ?? _cultivosOrg.first;

  final _areaDeclaradaCtrl = TextEditingController();

  /// Con polígono el área se calcula; con un solo punto se usa la declarada.
  double get _area => _puntos.length >= 3
      ? areaHectareas(_puntos)
      : double.tryParse(_areaDeclaradaCtrl.text.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
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
    // Sin moverse, el GPS igual "salta" unos metros: no se agrega ese punto.
    if (_puntos.isNotEmpty &&
        distanciaMetros(_puntos.last, punto) < distanciaMinimaGpsMetros) {
      _aviso(
        'Estás en el mismo punto que el anterior. Camina hasta la '
        'siguiente esquina del lindero.',
      );
      return;
    }
    setState(() => _puntos.add(punto));
    _mapCtrl.move(punto, 17);
  }

  /// Problema del polígono marcado, o `null` si es válido o todavía es un punto.
  ProblemaPoligono? get _problema =>
      _puntos.length >= 3 ? problemaPoligono(_puntos) : null;

  Future<void> _tomarFoto() async {
    final foto = await ref.read(fotosServiceProvider).tomar();
    if (foto != null) setState(() => _fotos.add(foto));
  }

  Future<void> _guardar() async {
    if (!widget.esLindero && _fincaCtrl.text.trim().isEmpty) {
      _aviso('Escribe el nombre de la finca.');
      return;
    }
    if (_puntos.isEmpty || _puntos.length == 2) {
      _aviso('Marca 1 punto (finca < 4 ha) o al menos 3 para el polígono.');
      return;
    }
    final problema = _problema;
    if (problema != null) {
      _aviso(problema.mensaje);
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

    if (widget.esLindero) {
      final LinderoNuevo nuevo = (
        coordenadasJson: aGeoJsonCoords(_puntos),
        areaHa: area,
        geoHash: geoHash(_puntos),
      );
      Navigator.of(context).pop(nuevo);
      return;
    }

    setState(() => _guardando = true);
    final db = ref.read(databaseProvider);
    final fincaId = const Uuid().v4();

    await db.transaction(() async {
      await db
          .into(db.fincas)
          .insert(
            FincasCompanion.insert(
              id: fincaId,
              productorId: widget.productorId!,
              nombre: _fincaCtrl.text.trim(),
              cultivo: Value(_cultivo),
              coordenadasJson: aGeoJsonCoords(_puntos),
              areaHa: area,
              geoHash: geoHash(_puntos),
            ),
          );
      for (final foto in _fotos) {
        await db
            .into(db.fotos)
            .insert(
              FotosService.registro(
                foto,
                entidadTipo: 'finca',
                entidadId: fincaId,
                tipo: 'finca',
              ),
            );
      }
    });

    if (mounted) Navigator.of(context).pop();
  }

  void _aviso(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    final esPoligono = _puntos.length >= 3;
    final problema = _problema;
    // Amarillo y rojo se distinguen bien sobre la imagen satelital.
    final colorBorde = problema == null
        ? Colors.yellowAccent
        : Colors.red.shade600;
    final sesionMapa = ref.watch(sesionMapaProvider).value;
    final cultivos =
        ref.watch(cultivosOrganizacionProvider).value ??
        const [cultivoPorDefecto];

    final anterior = widget.linderoAnterior;
    // En modo lindero, el mapa arranca sobre la finca.
    final centro = anterior == null || anterior.isEmpty
        ? _centroInicial
        : LatLng(
            anterior.map((p) => p.latitude).reduce((a, b) => a + b) /
                anterior.length,
            anterior.map((p) => p.longitude).reduce((a, b) => a + b) /
                anterior.length,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esLindero ? 'Nuevo lindero' : 'Nueva finca'),
      ),
      body: Column(
        children: [
          if (widget.esLindero)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'El lindero anterior se ve en blanco. Marca el nuevo siguiendo el borde actual; '
                'el anterior se conserva en el historial.',
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fincaCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la finca',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Foto de la finca',
                    onPressed: _tomarFoto,
                    icon: Badge(
                      isLabelVisible: _fotos.isNotEmpty,
                      label: Text('${_fotos.length}'),
                      child: const Icon(Icons.photo_camera),
                    ),
                  ),
                ],
              ),
            ),
          // El cultivo siempre se ve; solo se elige si la organización
          // trabaja más de uno.
          if (!widget.esLindero && cultivos.length == 1)
            _CultivoUnico(
              cultivo: cultivoDe(cultivos.single),
              esAdmin: ref.watch(sesionProvider).value?.esAdmin ?? false,
            )
          else if (!widget.esLindero)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<String>(
                segments: [
                  for (final c in cultivos.map(cultivoDe))
                    ButtonSegment(
                      value: c.id,
                      icon: Icon(c.icono, color: c.colorUi),
                      label: Text(c.nombre),
                    ),
                ],
                selected: {_cultivo},
                onSelectionChanged: (s) =>
                    setState(() => _cultivoElegido = s.first),
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: centro,
                initialZoom: anterior == null ? 14 : 17,
                onTap: (_, punto) => setState(() => _puntos.add(punto)),
              ),
              children: [
                if (sesionMapa != null) capaGoogle(sesionMapa),
                if (anterior != null && anterior.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: anterior,
                        color: Colors.white.withValues(alpha: 0.1),
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                        pattern: StrokePattern.dashed(segments: const [10, 6]),
                      ),
                    ],
                  ),
                if (esPoligono)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _puntos,
                        color: colorBorde.withValues(alpha: 0.25),
                        borderColor: colorBorde,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                // Puntos numerados en el orden marcado: así se ve dónde se
                // cruzan los linderos.
                MarkerLayer(
                  markers: [
                    for (final (i, p) in _puntos.indexed)
                      Marker(
                        point: p,
                        width: 22,
                        height: 22,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i == 0 ? Colors.blue.shade700 : Colors.brown,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (sesionMapa != null)
                  AtribucionGoogle(
                    sesion: sesionMapa,
                    servicio: ref.read(mapasServiceProvider),
                  )
                else
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Card(
                      margin: EdgeInsets.all(8),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Sin señal: el mapa no carga, pero puedes marcar\nlos linderos con "Agregar mi ubicación".',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Android 15+ dibuja la app detrás de la barra de navegación del
          // sistema; SafeArea deja el panel (y el botón Guardar) por encima.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (problema != null)
                    Text(
                      problema.mensaje,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else if (esPoligono)
                    Text('Área: ${_area.toStringAsFixed(2)} ha')
                  else
                    TextField(
                      controller: _areaDeclaradaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Área declarada (ha)',
                        helperText:
                            'Puntos: ${_puntos.length}. Un solo punto '
                            'solo se permite si la finca mide menos de 4 ha.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _guardando || problema != null
                          ? null
                          : _guardar,
                      child: Text(
                        widget.esLindero
                            ? 'Usar este lindero'
                            : 'Guardar finca',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cultivo fijo cuando la organización trabaja uno solo. Al administrador le
/// indica dónde activar otros.
class _CultivoUnico extends StatelessWidget {
  const _CultivoUnico({required this.cultivo, required this.esAdmin});

  final Cultivo cultivo;
  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    final pequeno = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(cultivo.icono, color: cultivo.colorUi, size: 20),
          const SizedBox(width: 6),
          Text(
            'Cultivo: ${cultivo.nombre}',
            style: TextStyle(
              color: cultivo.colorUi,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (esAdmin) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Activa más cultivos en ⋮ → Cultivos',
                style: pequeno,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
