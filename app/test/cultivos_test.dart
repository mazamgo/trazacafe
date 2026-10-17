import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/domain/cultivos.dart';

/// cultivos_generados.dart debe ser igual a schemas/cultivos.json, que es lo
/// que valida la API. Si falla: `npm run cultivos-dart --workspace schemas`.
void main() {
  final json = jsonDecode(
    File('../schemas/cultivos.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('mismos cultivos, en el mismo orden', () {
    expect(todosLosCultivos.map((c) => c.id), json.keys);
  });

  for (final MapEntry(key: id, value: c) in json.entries) {
    test('$id coincide con cultivos.json', () {
      final cultivo = cultivoDe(id);
      expect(cultivo.nombre, c['nombre']);
      expect(cultivo.codigoHS, c['codigoHS']);
      expect(cultivo.maxKgEntrega, c['maxKgEntrega']);
      final hex = (c['color'] as String).substring(1);
      expect(cultivo.color, 0xFF000000 | int.parse(hex, radix: 16));
      expect(
        [for (final e in cultivo.estados) [e.id, e.nombre, e.corto]],
        [for (final e in c['estados'] as List) [e['id'], e['nombre'], e['corto']]],
      );
    });
  }

  test('un cultivo desconocido (datos viejos) se muestra como café', () {
    expect(cultivoDe('soya').id, cultivoPorDefecto);
    expect(cultivoDe('cacao').nombreEstado('fermentado'), 'Fermentado');
    expect(cultivoDe('cafe').nombreEstado('raro'), 'raro');
  });
}
