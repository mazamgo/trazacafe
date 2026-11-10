import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Pendientes de la red de proveedores (invitaciones, lotes por recibir y
/// observaciones sin responder) para el inicio del celular y el panel web.
/// [abrir] recibe la sección: `clientes`, `proveedores` u `observaciones`.
class BannerRed extends StatelessWidget {
  const BannerRed({super.key, required this.avisos, required this.abrir});

  final AvisosRed avisos;
  final void Function(String seccion) abrir;

  @override
  Widget build(BuildContext context) {
    final red = avisos;
    return MaterialBanner(
      leading: const Icon(Icons.handshake_outlined),
      content: Text(
        [
          for (final o in red.invitaciones) '$o te invitó como proveedora.',
          if (red.lotesPorRecibir > 0)
            '${red.lotesPorRecibir} ${red.lotesPorRecibir == 1 ? 'lote' : 'lotes'} '
                'de proveedores por recibir.',
          if (red.observacionesSinResponder > 0)
            '${red.observacionesSinResponder} '
                '${red.observacionesSinResponder == 1 ? 'observación' : 'observaciones'} '
                'de tus clientes sin responder.',
        ].join('\n'),
      ),
      actions: [
        if (red.invitaciones.isNotEmpty)
          TextButton(
            onPressed: () => abrir('clientes'),
            child: const Text('Clientes'),
          ),
        if (red.lotesPorRecibir > 0)
          TextButton(
            onPressed: () => abrir('proveedores'),
            child: const Text('Recibir'),
          ),
        if (red.observacionesSinResponder > 0)
          TextButton(
            onPressed: () => abrir('observaciones'),
            child: const Text('Responder'),
          ),
      ],
    );
  }
}
