import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../domain/busqueda_lugar.dart';
import '../domain/cultivos.dart';
import '../domain/geo.dart';
import '../providers.dart';
import '../services/fotos_service.dart';
import '../services/lugares_service.dart';
import '../widgets/buscador_mapa.dart';
import '../widgets/mapa_google.dart';

/// Lindero dibujado en modo "nuevo lindero" (se devuelve, no se guarda aquí).
typedef LinderoNuevo = ({
  String coordenadasJson,
  double areaHa,
  String geoHash,
});

/// Registro de una finca: el técnico marca los vértices tocando el mapa o
/// caminando el lindero con "Agregar mi ubicación". Para llegar rápido al
/// terreno: el mapa abre cerca (otra finca del productor, su comunidad o la
/// última vista), y están la lupa y "Ir a mi ubicación".
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
  // Solo la primera vez, si no hay nada mejor: Jinotega.
  static const _centroInicial = LatLng(13.0910, -86.0023);

  final _fincaCtrl = TextEditingController();
  final _mapCtrl = MapController();
  final _puntos = <LatLng>[];
  final _fotos = <FotoTomada>[];
  bool _guardando = false;

  /// Lugar elegido en el buscador o la ubicación del técnico: un pin, no un
  /// vértice.
  DestinoMapa? _destino;

  /// El técnico ya movió el mapa: el inicio calculado no lo mueve después.
  bool _movido = false;
  MapCamera? _camara;
  late final Future<VistaMapa?> _inicio = _calcularInicio();

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
    // El próximo registro abre donde quedó este.
    if (_camara case final c?) {
      _lugares.guardarVista(c.center, c.zoom);
    }
    _fincaCtrl.dispose();
    _areaDeclaradaCtrl.dispose();
    super.dispose();
  }

  // Se lee al abrir: en dispose ya no se puede usar ref.
  late final LugaresService _lugares;

  @override
  void initState() {
    super.initState();
    _lugares = ref.read(lugaresServiceProvider);
  }

  /// Dónde abrir el mapa, en orden: otra finca del productor, fincas de su
  /// comunidad, la comunidad en la lista de lugares, la última vista.
  Future<VistaMapa?> _calcularInicio() async {
    if (widget.esLindero) return null;
    final id = widget.productorId!;
    final fincas = await ref.read(fincasReferenciaProvider.future);
    final suyas = [
      for (final f in fincas)
        if (f.productor.id == id) f,
    ]..sort((a, b) => b.finca.creadoEn.compareTo(a.finca.creadoEn));
    if (suyas.isNotEmpty) return (centro: suyas.first.centro, zoom: 16.0);

    final db = ref.read(databaseProvider);
    final productor = await (db.select(
      db.productores,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    final comunidad = normalizar(productor?.comunidad ?? '');
    if (comunidad.isNotEmpty) {
      final vecinas = [
        for (final f in fincas)
          if (normalizar(f.productor.comunidad ?? '') == comunidad) f.centro,
      ];
      if (vecinas.isNotEmpty) {
        return (centro: _promedio(vecinas), zoom: 15.0);
      }
      final lugares = await ref.read(lugaresProvider.future);
      for (final l in buscarLugares(lugares, comunidad, max: 1)) {
        if (normalizar(l.nombre) == comunidad) {
          return (centro: l.punto, zoom: 15.0);
        }
      }
    }
    return _lugares.ultimaVista();
  }

  static LatLng _promedio(List<LatLng> puntos) => LatLng(
    puntos.map((p) => p.latitude).reduce((a, b) => a + b) / puntos.length,
    puntos.map((p) => p.longitude).reduce((a, b) => a + b) / puntos.length,
  );

  Future<void> _alAbrirMapa() async {
    try {
      final inicio = await _inicio;
      if (inicio != null && mounted && !_movido) {
        _mapCtrl.move(inicio.centro, inicio.zoom);
      }
    } catch (_) {
      // Sin inicio calculado (o la pantalla se cerró antes) el mapa se queda
      // donde abrió.
    }
  }

  Future<bool> _permisoUbicacion() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      _aviso('Sin permiso de ubicación.');
      return false;
    }
    return true;
  }

  /// Lleva el mapa a donde está el técnico, sin marcar un vértice. Usa
  /// primero la última posición conocida (es instantánea) y después afina.
  Future<void> _irAMiUbicacion() async {
    if (!await _permisoUbicacion()) return;
    void ir(Position pos) {
      if (!mounted) return;
      final punto = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _movido = true;
        _destino = (
          punto: punto,
          zoom: 17,
          etiqueta: 'Estás aquí',
          encuadre: null,
        );
      });
      _mapCtrl.move(punto, 17);
    }

    final conocida = await Geolocator.getLastKnownPosition();
    if (conocida != null) ir(conocida);
    try {
      ir(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        ),
      );
    } on Exception {
      if (conocida == null) {
        _aviso('No se pudo leer el GPS. Sal a un lugar abierto.');
      }
    }
  }

  Future<void> _buscar() async {
    final destino = await buscarEnMapa(context);
    if (destino == null || !mounted) return;
    setState(() {
      _movido = true;
      _destino = destino;
    });
    final encuadre = destino.encuadre;
    if (encuadre != null) {
      _mapCtrl.fitCamera(
        CameraFit.coordinates(
          coordinates: encuadre,
          padding: const EdgeInsets.all(48),
          maxZoom: 18,
        ),
      );
    } else {
      _mapCtrl.move(destino.punto, destino.zoom);
    }
  }

  Future<void> _agregarMiUbicacion() async {
    if (!await _permisoUbicacion()) return;
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

  /// En modo lindero no se repite la propia finca (ya se ve en blanco).
  List<FincaReferencia> _fincasVecinas(List<FincaReferencia> todas) {
    final anterior = widget.linderoAnterior;
    if (anterior == null || anterior.isEmpty) return todas;
    final propia = _promedio(anterior);
    return [
      for (final f in todas)
        if (distanciaMetros(f.centro, propia) > 1) f,
    ];
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
    final vecinas = _fincasVecinas(
      ref.watch(fincasReferenciaProvider).value ?? const [],
    );

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
        actions: [
          IconButton(
            tooltip: 'Buscar lugar',
            onPressed: _buscar,
            icon: const Icon(Icons.search),
          ),
        ],
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
                onMapReady: _alAbrirMapa,
                onPositionChanged: (camara, conGesto) {
                  _camara = camara;
                  if (conGesto) _movido = true;
                },
              ),
              children: [
                if (sesionMapa != null) capaGoogle(sesionMapa),
                // Fincas ya registradas, en gris: para ubicarse y no
                // registrar dos veces el mismo terreno.
                PolygonLayer(
                  polygons: [
                    for (final f in vecinas)
                      if (f.puntos.length >= 3)
                        Polygon(
                          points: f.puntos,
                          color: Colors.white.withValues(alpha: 0.08),
                          borderColor: Colors.grey.shade300,
                          borderStrokeWidth: 1.5,
                        ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final f in vecinas)
                      Marker(
                        point: f.centro,
                        width: 140,
                        height: 36,
                        child: _EtiquetaVecina(f.finca.nombre),
                      ),
                  ],
                ),
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
                if (_destino case final d?)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: d.punto,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: Tooltip(
                          message: d.etiqueta,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.lightBlueAccent,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
                    child: FloatingActionButton.small(
                      heroTag: null,
                      tooltip: 'Ir a mi ubicación',
                      onPressed: _irAMiUbicacion,
                      child: const Icon(Icons.gps_fixed),
                    ),
                  ),
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

/// Nombre de una finca ya registrada, sobre el mapa.
class _EtiquetaVecina extends StatelessWidget {
  const _EtiquetaVecina(this.nombre);

  final String nombre;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      nombre,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        shadows: [Shadow(blurRadius: 3)],
      ),
    ),
  );
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
