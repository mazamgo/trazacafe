import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/cultivos.dart';
import '../services/preferencias.dart';
import '../services/verificador_service.dart';
import 'verificador_textos.dart';

/// Verificador público (Flutter Web): se abre al escanear el QR del
/// contenedor o del saco en `/v/{uid}`. Muestra la cadena firmada sin datos
/// personales y la compara, aparte, con la blockchain. En español o inglés,
/// con tema claro u oscuro.
class VerificadorScreen extends ConsumerStatefulWidget {
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
  ConsumerState<VerificadorScreen> createState() => _VerificadorScreenState();
}

typedef _Resultado = ({CadenaPublica cadena, Comprobacion? comprobacion});

class _VerificadorScreenState extends ConsumerState<VerificadorScreen> {
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
    final t = Textos.de(ref.watch(idiomaProvider));
    return Scaffold(
      appBar: AppBar(
        // En dos líneas: en un celular, en una sola se cortaba.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TrazaCafé'),
            Text(t.titulo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(idiomaProvider.notifier)
                .elegir(t.idioma == 'es' ? 'en' : 'es'),
            child: Text(t.idiomaOtro),
          ),
          _MenuTema(t: t),
        ],
      ),
      body: widget.uid == null
          ? _Mensaje(icono: Icons.qr_code_scanner, texto: t.escanea)
          : FutureBuilder<_Resultado>(
              future: _carga,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.hasError) {
                  final noEsta = s.error is NoEncontrado;
                  return _Mensaje(
                    icono: noEsta ? Icons.search_off : Icons.cloud_off,
                    texto: noEsta ? t.noEncontrado : t.errorCarga,
                  );
                }
                return _Cadena(
                  resultado: s.data!,
                  red: _servicio.red,
                  t: t,
                  mostrarMapa: widget.mostrarMapa,
                );
              },
            ),
    );
  }
}

class _MenuTema extends ConsumerWidget {
  const _MenuTema({required this.t});

  final Textos t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(temaProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: t.tema,
      icon: Icon(switch (actual) {
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.system => Icons.brightness_auto,
      }),
      initialValue: actual,
      onSelected: (m) => ref.read(temaProvider.notifier).elegir(m),
      itemBuilder: (_) => [
        for (final (modo, icono, texto) in [
          (ThemeMode.system, Icons.brightness_auto, t.temaAutomatico),
          (ThemeMode.light, Icons.light_mode, t.temaClaro),
          (ThemeMode.dark, Icons.dark_mode, t.temaOscuro),
        ])
          PopupMenuItem(
            value: modo,
            child: ListTile(
              leading: Icon(icono),
              title: Text(texto),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
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

Future<void> _abrir(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Fondo de un aviso que se lea bien en tema claro y oscuro.
Color _fondo(BuildContext context, MaterialColor color) =>
    Theme.of(context).brightness == Brightness.dark
    ? color.shade900.withValues(alpha: 0.45)
    : color.shade50;

class _Cadena extends StatelessWidget {
  const _Cadena({
    required this.resultado,
    required this.red,
    required this.t,
    required this.mostrarMapa,
  });

  final _Resultado resultado;
  final RedEas red;
  final Textos t;
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
                color: _fondo(context, Colors.amber),
                child: ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: Text(t.redPrueba),
                  subtitle: Text(t.redPruebaDetalle),
                ),
              ),
            Card(
              child: ListTile(
                leading: Icon(cultivo.icono, color: cultivo.colorUi, size: 36),
                title: Text(
                  x != null
                      ? t.contenedor(x.contenedor)
                      : t.lote(c.lotes.first.codigo),
                  style: titulo,
                ),
                subtitle: Text(
                  [
                    '${t.cultivo(cultivo)} · '
                        '${_kg(x?.kg ?? c.lotes.first.kg)} kg',
                    if (x != null) t.destino(x.destino),
                    if (x != null) t.dds(x.ddsRef),
                    if (x?.fechaEmbarque != null)
                      t.embarque(_fecha(x!.fechaEmbarque!)),
                    t.exportador(c.organizacion),
                  ].join('\n'),
                ),
                isThreeLine: true,
              ),
            ),
            _TarjetaComprobacion(
              comprobacion: resultado.comprobacion,
              enlace: red.attestation(c.uid),
              t: t,
            ),
            if (mostrarMapa && c.fincas.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MapaFincas(fincas: c.fincas),
            ],
            const SizedBox(height: 16),
            Text(t.lotes(c.lotes.length), style: titulo),
            for (final l in c.lotes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${l.codigo} · ${_kg(l.kg)} kg ${t.estado(cultivo, l.estado)}',
                ),
                subtitle: Text(
                  '${t.temporada(l.temporada)} · ${l.beneficio}'
                  '${l.proceso == null ? '' : ' · ${l.proceso}'}',
                ),
                trailing: l.firma == null
                    ? null
                    : _BotonFirma(enlace: red.attestation(l.firma!.uid), t: t),
              ),
            const SizedBox(height: 8),
            Text(t.fincasDeOrigen(c.fincas.length), style: titulo),
            for (final (i, f) in c.fincas.indexed)
              _TarjetaFinca(
                numero: i + 1,
                finca: f,
                cultivo: cultivo,
                red: red,
                t: t,
              ),
            const SizedBox(height: 16),
            Text(t.privacidad, style: Theme.of(context).textTheme.bodySmall),
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
    required this.t,
  });

  final Comprobacion? comprobacion;
  final String enlace;
  final Textos t;

  @override
  Widget build(BuildContext context) {
    final c = comprobacion;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final (color, icono, titulo) = switch (c) {
      null => (
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Icons.cloud_off,
        t.sinBlockchain,
      ),
      Comprobacion(valida: true) => (
        _fondo(context, Colors.green),
        Icons.verified,
        t.verificado,
      ),
      _ => (_fondo(context, Colors.red), Icons.gpp_bad, t.noCoincide),
    };
    Widget punto(bool ok, String texto) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check : Icons.close,
          size: 18,
          color: ok
              ? (oscuro ? Colors.green.shade300 : Colors.green.shade800)
              : (oscuro ? Colors.red.shade300 : Colors.red.shade800),
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
              Text(t.revisarExplorador)
            else if (!c.existe)
              punto(false, t.noExiste)
            else ...[
              punto(
                c.firmanteOficial,
                c.firmanteOficial
                    ? t.firmadoPor(
                        _corto(atestadorOficial),
                        _fecha(c.firmadaEn!),
                      )
                    : t.noFirmoTrazaCafe,
              ),
              punto(c.vigente, c.vigente ? t.vigente : t.revocado),
              punto(
                c.esquemaCorrecto && c.diferencias.isEmpty,
                c.diferencias.isEmpty && c.esquemaCorrecto
                    ? t.coinciden
                    : t.noCoinciden([
                        if (!c.esquemaCorrecto) 'tipo',
                        ...c.diferencias,
                      ]),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _abrir(enlace),
                icon: const Icon(Icons.open_in_new),
                label: Text(t.verExplorador),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonFirma extends StatelessWidget {
  const _BotonFirma({required this.enlace, required this.t});

  final String enlace;
  final Textos t;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: t.verBlockchain,
    icon: const Icon(Icons.link),
    onPressed: () => _abrir(enlace),
  );
}

class _TarjetaFinca extends StatelessWidget {
  const _TarjetaFinca({
    required this.numero,
    required this.finca,
    required this.cultivo,
    required this.red,
    required this.t,
  });

  /// Las fincas vienen de la API ordenadas como "Finca 1", "Finca 2"…
  final int numero;
  final FincaPublica finca;
  final Cultivo cultivo;
  final RedEas red;
  final Textos t;

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
          : _BotonFirma(enlace: red.attestation(firma.uid), t: t),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.finca(numero, f.areaHa.toStringAsFixed(2), _kg(f.kg)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            fila(Icons.crop_square, t.lindero(f.version), f.firma),
            fila(
              Icons.satellite_alt,
              ch == null
                  ? t.deforestacion(f.deforestacion)
                  : '${t.deforestacion(ch.resultado)} · ${ch.fuente} · '
                        '${_fecha(ch.fecha)}',
              ch?.firma,
            ),
            if (v != null)
              fila(
                Icons.fact_check_outlined,
                t.visita(_fecha(v.fecha)),
                v.firma,
              ),
            for (final e in f.entregas)
              fila(
                Icons.local_shipping_outlined,
                t.entrega(
                  _fecha(e.fecha),
                  _kg(e.kg),
                  t.estado(cultivo, e.estado),
                ),
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
