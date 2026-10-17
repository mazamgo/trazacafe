import 'package:flutter/material.dart';

part 'cultivos_generados.dart';

/// Estado en que se entrega el producto (p. ej. café en uva o cacao en baba).
class EstadoEntrega {
  const EstadoEntrega({
    required this.id,
    required this.nombre,
    required this.corto,
    required this.factorExportable,
  });
  final String id;
  final String nombre;
  final String corto;

  /// Kg del producto exportable (café oro, cacao seco) que rinde 1 kg en este
  /// estado. Mismo valor que usa la API para el control de volumen de lotes.
  final double factorExportable;
}

/// Cultivo que maneja la plataforma. La lista sale de `schemas/cultivos.json`
/// (la misma que valida la API); ver `cultivos_generados.dart`.
class Cultivo {
  const Cultivo({
    required this.id,
    required this.nombre,
    required this.codigoHS,
    required this.color,
    required this.maxKgEntrega,
    required this.maxKgExportableHa,
    required this.estados,
  });

  final String id;
  final String nombre;
  final String codigoHS;
  final int color;
  final int maxKgEntrega;

  /// Rendimiento máximo razonable por temporada (kg exportables por ha).
  final int maxKgExportableHa;
  final List<EstadoEntrega> estados;

  Color get colorUi => Color(color);

  IconData get icono => switch (id) {
    'cafe' => Icons.coffee,
    'cacao' => Icons.spa,
    _ => Icons.agriculture,
  };

  String nombreEstado(String estado) =>
      estados.where((e) => e.id == estado).firstOrNull?.nombre ?? estado;

  /// Kg en [destino] que rinden [kg] en [origen] (p. ej. 500 kg de uva rinden
  /// unos 100 kg de pergamino). Igual que `convertirKg` de la API.
  double convertirKg(double kg, String origen, String destino) {
    double factor(String id) =>
        estados.firstWhere((e) => e.id == id).factorExportable;
    return kg * factor(origen) / factor(destino);
  }
}

const cultivoPorDefecto = 'cafe';

List<Cultivo> get todosLosCultivos => cultivosGenerados;

/// El cultivo con ese id; si no existe (datos viejos), el café.
Cultivo cultivoDe(String id) =>
    cultivosGenerados.where((c) => c.id == id).firstOrNull ??
    cultivosGenerados.firstWhere((c) => c.id == cultivoPorDefecto);
