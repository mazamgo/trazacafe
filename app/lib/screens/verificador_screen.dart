import 'package:flutter/material.dart';

/// Verificador público (Flutter Web): se abre al escanear el QR del saco o
/// contenedor en `/v/{uid}`. Por ahora muestra el UID y el enlace a EAS; en
/// la semana 6 consultará la API y mostrará la cadena completa.
class VerificadorScreen extends StatelessWidget {
  const VerificadorScreen({super.key, required this.uid});

  final String? uid;

  static const _easScan = 'https://optimism.easscan.org/attestation/view/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar origen del café')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: uid == null
              ? const Text('Escanea el código QR del saco para ver su origen.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 48),
                    const SizedBox(height: 12),
                    const Text('Registro en la blockchain (OP Mainnet)'),
                    const SizedBox(height: 8),
                    SelectableText(uid!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    SelectableText(
                      '$_easScan$uid',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
