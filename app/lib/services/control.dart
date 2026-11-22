import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';

/// Finca de un lote recibido, para elegirla en el muestreo (exportadora).
class FincaMuestreo {
  FincaMuestreo.desdeJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      nombre = j['nombre'] as String,
      productorNombre = j['productorNombre'] as String?,
      comunidad = j['comunidad'] as String?,
      temporadaNombre = j['temporadaNombre'] as String,
      deforestacion = j['deforestacion'] as String,
      elegida = j['elegida'] as bool,
      controles = j['controles'] as int;

  final String id;
  final String nombre;
  final String? productorNombre;
  final String? comunidad;
  final String temporadaNombre;
  final String deforestacion;
  final bool elegida;
  final int controles;
}

/// Finca que deben visitar los técnicos de la exportadora; se guarda en el
/// celular para visitarla sin señal.
class FincaControl {
  FincaControl.desdeJson(this.json)
    : id = json['id'] as String,
      nombre = json['nombre'] as String,
      productorNombre = json['productorNombre'] as String?,
      comunidad = json['comunidad'] as String?,
      proveedor = json['proveedor'] as String,
      areaOficialHa = (json['areaOficialHa'] as num).toDouble(),
      temporadaNombre = json['temporadaNombre'] as String,
      visitada = json['visitada'] as bool,
      puntos = [
        for (final c in (json['coordenadas'] as List).cast<List>())
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];

  final Map<String, dynamic> json;
  final String id;
  final String nombre;
  final String? productorNombre;
  final String? comunidad;
  final String proveedor;
  final double areaOficialHa;
  final String temporadaNombre;
  final bool visitada;
  final List<LatLng> puntos;
}

/// Visita de control ya hecha (la ven la exportadora y la cooperativa).
class ControlVisita {
  ControlVisita.desdeJson(Map<String, dynamic> j)
    : finca = j['finca'] as String,
      fecha = DateTime.parse(j['fecha'] as String).toLocal(),
      linderoCambio = j['linderoCambio'] as bool,
      nota = j['nota'] as String?,
      por = j['por'] as String?;

  final String finca;
  final DateTime fecha;
  final bool linderoCambio;
  final String? nota;
  final String? por;
}

/// Lo que ve el técnico: las fincas y las visitas que faltan por enviar.
typedef EstadoControl = ({
  List<FincaControl> fincas,
  List<Map<String, dynamic>> pendientes,
  bool sinSenal,
});

/// Visitas de control sin señal: guarda en el celular las fincas por visitar
/// y las visitas hechas hasta enviarlas.
class ControlService {
  ControlService(this._api);

  final ApiClient _api;
  static const _kFincas = 'control.fincas';
  static const _kPendientes = 'control.pendientes';

  Future<List<Map<String, dynamic>>> _leer(String clave) async {
    final s = (await SharedPreferences.getInstance()).getString(clave);
    return s == null
        ? []
        : (jsonDecode(s) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _guardar(String clave, List<Map<String, dynamic>> lista) async =>
      (await SharedPreferences.getInstance()).setString(
        clave,
        jsonEncode(lista),
      );

  /// Envía lo pendiente y baja la lista; sin señal, la guardada.
  Future<EstadoControl> cargar() async {
    await enviarPendientes();
    var sinSenal = false;
    var fincas = await _leer(_kFincas);
    try {
      fincas = await _api.fincasControl();
      await _guardar(_kFincas, fincas);
    } catch (_) {
      sinSenal = true;
    }
    final pendientes = await _leer(_kPendientes);
    return (
      fincas: [for (final f in fincas) FincaControl.desdeJson(f)],
      pendientes: pendientes,
      sinSenal: sinSenal,
    );
  }

  /// Guarda la visita en el celular y trata de enviarla.
  Future<void> registrar({
    required String fincaId,
    required bool linderoCambio,
    String? nota,
  }) async {
    final pendientes = await _leer(_kPendientes);
    pendientes.add({
      'id': const Uuid().v4(),
      'fincaId': fincaId,
      'fecha': DateTime.now().toUtc().toIso8601String(),
      'linderoCambio': linderoCambio,
      'nota': ?nota,
    });
    await _guardar(_kPendientes, pendientes);
    await enviarPendientes();
  }

  /// Envía las visitas guardadas. Las que la API rechaza (por ejemplo, la
  /// finca salió del muestreo) se descartan; sin señal quedan para después.
  Future<void> enviarPendientes() async {
    final pendientes = await _leer(_kPendientes);
    final quedan = <Map<String, dynamic>>[];
    for (final v in pendientes) {
      try {
        await _api.registrarControl(v);
      } on ApiError catch (e) {
        if (e.status >= 500) quedan.add(v);
      } catch (_) {
        quedan.add(v);
      }
    }
    await _guardar(_kPendientes, quedan);
  }
}
