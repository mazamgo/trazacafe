import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/cultivos.dart';
import '../services/verificador_service.dart';

/// Verificador público (Flutter Web): se abre al escanear el QR del
/// contenedor o del saco en `/v/{uid}`. Muestra la cadena firmada sin datos
/// personales y la compara, aparte, con la blockchain.
class VerificadorScreen extends StatefulWidget {
  const VerificadorScreen({
    super.key,
    required this.uid,
    this.servicio,
    this.mostrarMapa = true,
  });

  final String? uid;
  final VerificadorService? servicio;

  /// Las pruebas no cargan mosaicos de OpenStreetMap.
  final bool mostrarMapa;

  @override
  State<VerificadorScreen> createState() => _VerificadorScreenState();
}

typedef _Resultado = ({CadenaPublica cadena, Comprobacion? comprobacion});

class _VerificadorScreenState extends State<VerificadorScreen> {
  late final VerificadorService _servicio =
      widget.servicio ?? VerificadorService();
  Future<_Resultado>? _carga;

  @override
  void initState() {
    super.initState();
    if (widget.uid != null) _carga = _cargar(widget.uid!);
  }

  Future<_Resultado> _cargar(String uid) async {
    final cadena = _servicio.cadena(uid);
    // La blockchain se consulta aparte: si su RPC falla, la página igual
    // muestra la cadena y avisa que no pudo comprobarla.
    final enCadena = _servicio
        .attestation(uid)
        .then<AttestationEnCadena?>((a) => a)
        .catchError((Object _) => null);
    final c = await cadena;
    final a = await enCadena;
    return (cadena: c, comprobacion: a == null ? null : comprobar(c, a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TrazaCafé · Verificar origen')),
      body: widget.uid == null
          ? const _Mensaje(
              icono: Icons.qr_code_scanner,
              texto:
                  'Escanea el código QR del contenedor o del saco para ver '
                  'de qué fincas viene y su registro en la blockchain.',
            )
          : FutureBuilder<_Resultado>(
              future: _carga,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.hasError) {
                  final e = s.error;
                  return _Mensaje(
                    icono: e is NoEncontrado
                        ? Icons.search_off
                        : Icons.cloud_off,
                    texto: e is NoEncontrado
                        ? e.mensaje
                        : 'No se pudo cargar la información. Revisa tu '
                              'conexión e inténtalo de nuevo.',
                  );
                }
                return _Cadena(
                  resultado: s.data!,
                  red: _servicio.red,
                  mostrarMapa: widget.mostrarMapa,
                );
              },
            ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _dos(int n) => n.toString().padLeft(2, '0');
String _fecha(DateTime f) {
  final l = f.toLocal();
  return '${_dos(l.day)}/${_dos(l.month)}/${l.year}';
}

String _kg(double kg) => kg.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String _corto(String hex) =>
    '${hex.substring(0, 6)}…${hex.substring(hex.length - 4)}';

String _textoDeforestacion(String resultado) => switch (resultado) {
  'verde' => 'Sin deforestación después de 2020',
  'amarillo' => 'Pérdida de bosque menor a 0.1 ha después de 2020',
  'rojo' => 'Deforestación después de 2020',
  _ => 'Chequeo satelital pendiente',
};

Future<void> _abrir(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class _Cadena extends StatelessWidget {
  const _Cadena({
    required this.resultado,
    required this.red,
    required this.mostrarMapa,
  });

  final _Resultado resultado;
  final RedEas red;
  final bool mostrarMapa;

  @override
  Widget build(BuildContext context) {
    final c = resultado.cadena;
    final cultivo = cultivoDe(c.cultivo);
    final x = c.exportacion;
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (red.dePrueba)
              Card(
                color: Colors.amber.shade100,
                child: const ListTile(
                  leading: Icon(Icons.science_outlined),
                  title: Text('Red de pruebas (OP Sepolia)'),
                  subtitle: Text(
                    'Estos registros son de prueba. En producción se firman '
                    'en OP Mainnet.',
                  ),
                ),
              ),
            Card(
              child: ListTile(
                leading: Icon(cultivo.icono, color: cultivo.colorUi, size: 36),
                title: Text(
                  x != null
                      ? 'Contenedor ${x.contenedor ?? 'sin número'}'
                      : 'Lote ${c.lotes.first.codigo}',
                  style: titulo,
                ),
                subtitle: Text(
                  [
                    '${cultivo.nombre} · '
                        '${_kg(x?.kg ?? c.lotes.first.kg)} kg',
                    if (x != null) 'Destino: ${x.destino}',
                    if (x != null) 'DDS (TRACES): ${x.ddsRef ?? 'pendiente'}',
                    if (x?.fechaEmbarque != null)
                      'Embarque: ${_fecha(x!.fechaEmbarque!)}',
                    'Exportador: ${c.organizacion}',
                  ].join('\n'),
                ),
                isThreeLine: true,
              ),
            ),
            _TarjetaComprobacion(
              comprobacion: resultado.comprobacion,
              enlace: red.attestation(c.uid),
            ),
            if (mostrarMapa && c.fincas.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MapaFincas(fincas: c.fincas),
            ],
            const SizedBox(height: 16),
            Text(c.lotes.length == 1 ? 'Lote' : 'Lotes', style: titulo),
            for (final l in c.lotes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${l.codigo} · ${_kg(l.kg)} kg '
                  '${cultivo.nombreEstado(l.estado).toLowerCase()}',
                ),
                subtitle: Text(
                  'Temporada ${l.temporada} · ${l.beneficio}'
                  '${l.proceso == null ? '' : ' · ${l.proceso}'}',
                ),
                trailing: l.firma == null
                    ? null
                    : _BotonFirma(enlace: red.attestation(l.firma!.uid)),
              ),
            const SizedBox(height: 8),
            Text('Fincas de origen (${c.fincas.length})', style: titulo),
            for (final f in c.fincas)
              _TarjetaFinca(finca: f, cultivo: cultivo, red: red),
            const SizedBox(height: 16),
            Text(
              'Esta página no muestra datos personales: ni nombres de '
              'productores o fincas, ni documentos de identidad. La ubicación '
              'es aproximada (~1 km); la geolocalización exacta va en la '
              'declaración de diligencia debida (EUDR) para las autoridades '
              'de la Unión Europea.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaComprobacion extends StatelessWidget {
  const _TarjetaComprobacion({
    required this.comprobacion,
    required this.enlace,
  });

  final Comprobacion? comprobacion;
  final String enlace;

  @override
  Widget build(BuildContext context) {
    final c = comprobacion;
    final (color, icono, titulo) = switch (c) {
      null => (
        Colors.grey.shade200,
        Icons.cloud_off,
        'No se pudo consultar la blockchain ahora',
      ),
      Comprobacion(valida: true) => (
        Colors.green.shade50,
        Icons.verified,
        'Verificado en la blockchain',
      ),
      _ => (
        Colors.red.shade50,
        Icons.gpp_bad,
        'Atención: no coincide con la blockchain',
      ),
    };
    Widget punto(bool ok, String texto) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check : Icons.close,
          size: 18,
          color: ok ? Colors.green.shade800 : Colors.red.shade800,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(texto)),
      ],
    );
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (c == null)
              const Text(
                'Los registros se pueden revisar directamente en el '
                'explorador de EAS.',
              )
            else if (!c.existe)
              punto(false, 'El código no existe en la blockchain.')
            else ...[
              punto(
                c.firmanteOficial,
                c.firmanteOficial
                    ? 'Firmado por TrazaCafé (${_corto(atestadorOficial)}) '
                          'el ${_fecha(c.firmadaEn!)}'
                    : 'No lo firmó la clave de TrazaCafé',
              ),
              punto(
                c.vigente,
                c.vigente ? 'Vigente (no revocado)' : 'Revocado',
              ),
              punto(
                c.esquemaCorrecto && c.diferencias.isEmpty,
                c.diferencias.isEmpty && c.esquemaCorrecto
                    ? 'Los datos de esta página coinciden con lo firmado'
                    : 'No coinciden: ${[if (!c.esquemaCorrecto) 'tipo de registro', ...c.diferencias].join(', ')}',
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _abrir(enlace),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ver en el explorador (EAS)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonFirma extends StatelessWidget {
  const _BotonFirma({required this.enlace});

  final String enlace;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Ver en la blockchain',
    icon: const Icon(Icons.link),
    onPressed: () => _abrir(enlace),
  );
}

class _TarjetaFinca extends StatelessWidget {
  const _TarjetaFinca({
    required this.finca,
    required this.cultivo,
    required this.red,
  });

  final FincaPublica finca;
  final Cultivo cultivo;
  final RedEas red;

  @override
  Widget build(BuildContext context) {
    final f = finca;
    final ch = f.chequeo;
    final v = f.visita;
    Widget fila(IconData icono, String texto, Firma? firma) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, size: 20),
      title: Text(texto),
      trailing: firma == null
          ? null
          : _BotonFirma(enlace: red.attestation(firma.uid)),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${f.alias} · ${f.areaHa.toStringAsFixed(2)} ha · '
              '${_kg(f.kg)} kg en este envío',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            fila(
              Icons.crop_square,
              'Lindero georreferenciado (versión ${f.version})',
              f.firma,
            ),
            fila(
              Icons.satellite_alt,
              ch == null
                  ? _textoDeforestacion(f.deforestacion)
                  : '${_textoDeforestacion(ch.resultado)} · ${ch.fuente} · '
                        '${_fecha(ch.fecha)}',
              ch?.firma,
            ),
            if (v != null)
              fila(
                Icons.fact_check_outlined,
                'Visita de verificación: ${_fecha(v.fecha)}',
                v.firma,
              ),
            for (final e in f.entregas)
              fila(
                Icons.local_shipping_outlined,
                'Entrega ${_fecha(e.fecha)} · ${_kg(e.kg)} kg '
                '${cultivo.nombreEstado(e.estado).toLowerCase()}',
                e.firma,
              ),
          ],
        ),
      ),
    );
  }
}

/// Ubicación aproximada de las fincas: un círculo de ~1 km sobre
/// OpenStreetMap (la key de Google Map Tiles es solo para la app Android).
class _MapaFincas extends StatelessWidget {
  const _MapaFincas({required this.fincas});

  final List<FincaPublica> fincas;

  @override
  Widget build(BuildContext context) {
    final puntos = [for (final f in fincas) LatLng(f.lat, f.lon)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            // Con un solo punto no hay área que encuadrar: se centra en él.
            initialCenter: puntos.first,
            initialZoom: 11,
            initialCameraFit: puntos.length < 2
                ? null
                : CameraFit.coordinates(
                    coordinates: puntos,
                    padding: const EdgeInsets.all(48),
                    maxZoom: 11,
                  ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.goproduction.trazacafe',
            ),
            CircleLayer(
              circles: [
                for (final p in puntos)
                  CircleMarker(
                    point: p,
                    radius: 1000,
                    useRadiusInMeter: true,
                    color: Colors.green.withValues(alpha: 0.3),
                    borderColor: Colors.green.shade800,
                    borderStrokeWidth: 2,
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => _abrir('https://openstreetmap.org/copyright'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
