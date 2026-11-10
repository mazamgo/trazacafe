import 'package:flutter/material.dart';

import '../domain/cultivos.dart';
import '../screens/finca_screen.dart' show fecha;
import '../screens/lotes_screen.dart' show kgTexto;
import '../services/api_client.dart';

/// Igual que TOLERANCIA_VOLUMEN de la API (backend/src/lotes.ts).
const toleranciaVolumen = 0.1;

/// Entregas de un cultivo y temporada para elegir las de un lote: las libres
/// con su casilla y las excluidas con el motivo.
class ListaEntregas extends StatelessWidget {
  const ListaEntregas({
    super.key,
    required this.cultivo,
    required this.entregas,
    required this.elegidas,
    required this.cambiar,
  });

  final Cultivo cultivo;
  final List<EntregaDisponible> entregas;
  final Set<String> elegidas;

  /// Aplica un cambio a [elegidas] y redibuja la pantalla.
  final void Function(void Function()) cambiar;

  @override
  Widget build(BuildContext context) {
    final libres = [
      for (final e in entregas)
        if (e.motivo == null) e,
    ];
    final excluidas = [
      for (final e in entregas)
        if (e.motivo != null) e,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Entregas disponibles (${libres.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (libres.isNotEmpty)
              TextButton(
                onPressed: () => cambiar(() {
                  if (elegidas.length == libres.length) {
                    elegidas.clear();
                  } else {
                    elegidas.addAll(libres.map((e) => e.id));
                  }
                }),
                child: Text(
                  elegidas.length == libres.length
                      ? 'Quitar todas'
                      : 'Elegir todas',
                ),
              ),
          ],
        ),
        if (libres.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No hay entregas libres en esta temporada.'),
          ),
        for (final e in libres)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: elegidas.contains(e.id),
            onChanged: (v) => cambiar(
              () => v == true ? elegidas.add(e.id) : elegidas.remove(e.id),
            ),
            title: Text(
              '${e.fincaNombre} · ${kgTexto(e.kg)} kg ${cultivo.nombreEstado(e.estado).toLowerCase()}',
            ),
            subtitle: Text(
              '${e.productorNombre} · ${fecha(e.fecha)}'
              '${e.deforestacion == 'verde' ? '' : ' · satélite: ${e.deforestacion}'}',
            ),
          ),
        if (excluidas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'No pueden ir en un lote (${excluidas.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final e in excluidas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: false,
              leading: const Icon(Icons.block),
              title: Text('${e.fincaNombre} · ${kgTexto(e.kg)} kg'),
              subtitle: Text(e.motivo!),
            ),
        ],
      ],
    );
  }
}
