import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../domain/busqueda_lugar.dart';
import '../providers.dart';
import '../services/lugares_service.dart';

/// A dónde llevar el mapa. Con [encuadre], el mapa muestra esa finca entera.
typedef DestinoMapa = ({
  LatLng punto,
  double zoom,
  String etiqueta,
  List<LatLng>? encuadre,
});

/// Abre el buscador: fincas de la cooperativa, lugares de Nicaragua y
/// coordenadas o enlaces pegados. Todo funciona sin señal menos los enlaces
/// cortos de Google Maps.
Future<DestinoMapa?> buscarEnMapa(BuildContext context) =>
    showSearch<DestinoMapa?>(context: context, delegate: _Buscador());

class _Buscador extends SearchDelegate<DestinoMapa?> {
  _Buscador()
    : super(
        searchFieldLabel: 'Comunidad, finca o coordenadas',
        keyboardType: TextInputType.text,
      );

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Borrar',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Volver',
    onPressed: () => close(context, null),
    icon: const BackButtonIcon(),
  );

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _Resultados(texto: query, elegir: (d) => close(context, d));
}

class _Resultados extends ConsumerWidget {
  const _Resultados({required this.texto, required this.elegir});

  final String texto;
  final void Function(DestinoMapa) elegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pequeno = Theme.of(context).textTheme.bodySmall;
    if (normalizar(texto).length < 2) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Escribe el nombre de una comunidad, comarca o pueblo, de una '
            'finca o de un productor. También puedes pegar coordenadas o la '
            'ubicación que te mandaron por WhatsApp.',
            style: pequeno,
          ),
        ],
      );
    }

    final coordenadas = parsearCoordenadas(texto);
    final fincas = buscarFincas(
      ref.watch(fincasReferenciaProvider).value ?? const [],
      texto,
    );
    final lugaresListos = ref.watch(lugaresProvider);
    final lugares = buscarLugares(lugaresListos.value ?? const [], texto);

    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(t, style: Theme.of(context).textTheme.titleSmall),
    );

    return ListView(
      children: [
        if (coordenadas != null)
          ListTile(
            leading: const Icon(Icons.pin_drop),
            title: Text(
              '${coordenadas.latitude.toStringAsFixed(5)}, '
              '${coordenadas.longitude.toStringAsFixed(5)}',
            ),
            subtitle: const Text('Ir a estas coordenadas'),
            onTap: () => elegir((
              punto: coordenadas,
              zoom: 17,
              etiqueta: 'Coordenadas',
              encuadre: null,
            )),
          )
        else if (esEnlaceCorto(texto))
          _EnlaceCorto(texto: texto, elegir: elegir),
        if (fincas.isNotEmpty) titulo('Fincas de la cooperativa'),
        for (final f in fincas)
          ListTile(
            leading: const Icon(Icons.agriculture),
            title: Text(f.finca.nombre),
            subtitle: Text(
              [
                f.productor.nombre,
                if (f.productor.comunidad case final c? when c.isNotEmpty) c,
              ].join(' · '),
            ),
            onTap: () => elegir((
              punto: f.centro,
              zoom: 16,
              etiqueta: f.finca.nombre,
              encuadre: f.puntos.length >= 3 ? f.puntos : null,
            )),
          ),
        if (lugares.isNotEmpty) titulo('Lugares'),
        for (final l in lugares)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(l.nombre),
            subtitle: l.detalle.isEmpty ? null : Text(l.detalle),
            onTap: () => elegir((
              punto: l.punto,
              zoom: 15,
              etiqueta: l.nombre,
              encuadre: null,
            )),
          ),
        if (lugaresListos.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (coordenadas == null &&
            !esEnlaceCorto(texto) &&
            fincas.isEmpty &&
            lugares.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No se encontró "$texto". Prueba con el municipio o con una '
              'comunidad cercana, o pega las coordenadas.',
            ),
          ),
        if (lugares.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Lugares: © colaboradores de OpenStreetMap',
              style: pequeno,
            ),
          ),
      ],
    );
  }
}

/// `maps.app.goo.gl/…` no trae las coordenadas: se abre con señal.
class _EnlaceCorto extends ConsumerStatefulWidget {
  const _EnlaceCorto({required this.texto, required this.elegir});

  final String texto;
  final void Function(DestinoMapa) elegir;

  @override
  ConsumerState<_EnlaceCorto> createState() => _EnlaceCortoState();
}

class _EnlaceCortoState extends ConsumerState<_EnlaceCorto> {
  bool _abriendo = false;
  bool _fallo = false;

  Future<void> _abrir() async {
    setState(() => _abriendo = true);
    final punto = await ref
        .read(lugaresServiceProvider)
        .resolverEnlace(widget.texto);
    if (!mounted) return;
    if (punto == null) {
      setState(() {
        _abriendo = false;
        _fallo = true;
      });
      return;
    }
    widget.elegir((
      punto: punto,
      zoom: 17,
      etiqueta: 'Ubicación del enlace',
      encuadre: null,
    ));
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _abriendo
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.link),
    title: const Text('Abrir el enlace de Google Maps'),
    subtitle: Text(
      _fallo
          ? 'No se pudo abrir (¿sin señal?). En Google Maps toca el punto y '
                'copia las coordenadas que aparecen arriba.'
          : 'Necesita señal.',
    ),
    onTap: _abriendo ? null : _abrir,
  );
}
