import 'package:flutter/material.dart';

import '../screens/finca_screen.dart' show fecha;
import '../services/api_client.dart';

/// Qué pasa al eliminar los datos de un productor. Las reglas están en la API
/// (backend/src/eliminacion.ts) y la página pública dice lo mismo.
const queSeBorraDelProductor =
    'Se borran su nombre, cédula, comunidad, las fotos del consentimiento, '
    'de sus fincas y de las visitas, y las fincas que no tienen entregas en '
    'lotes ni en la blockchain.\n\n'
    'Si alguna finca tiene entregas que ya están en un lote o en un '
    'contenedor, el EUDR obliga a guardar su ubicación y sus entregas 5 años: '
    'quedan sin ningún dato personal, como "Productor eliminado", y se borran '
    'solas al vencer el plazo.\n\n'
    'No se puede deshacer.';

/// Confirmación antes de eliminar o anonimizar a un productor.
Future<bool> confirmarEliminacionProductor(
  BuildContext context,
  String nombre,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.person_remove_outlined),
        title: Text('¿Eliminar los datos de $nombre?'),
        content: const SingleChildScrollView(
          child: Text(queSeBorraDelProductor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
              foregroundColor: Theme.of(c).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar datos'),
          ),
        ],
      ),
    ) ??
    false;

/// Mensaje para después de eliminar a un productor.
String resumenEliminacion(ResumenEliminacion r) => r.anonimizado
    ? 'Datos personales eliminados. ${r.fincasConservadas == 1 ? 'Queda 1 finca' : 'Quedan ${r.fincasConservadas} fincas'} '
          'sin datos personales por el EUDR, hasta el ${fecha(r.conservarHasta!)}.'
    : 'Se eliminaron el productor y ${r.fincasBorradas == 1 ? 'su finca' : 'sus ${r.fincasBorradas} fincas'}.';
