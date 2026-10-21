import 'package:flutter/material.dart';

import 'eliminar_datos_screen.dart';

/// Política de privacidad pública (`/privacidad`), que exige Google Play.
/// BORRADOR: revisarla con el abogado antes de publicar la app (plan, Fase 0).
class PrivacidadPublicaScreen extends StatelessWidget {
  const PrivacidadPublicaScreen({super.key});

  static const actualizada = '21 de octubre de 2026';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget titulo(String texto) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(texto, style: t.titleMedium),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('TrazaCafé · Privacidad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Política de privacidad de TrazaCafé',
                  style: t.headlineSmall,
                ),
                Text('Actualizada el $actualizada', style: t.bodySmall),
                titulo('Quiénes somos'),
                const Text(
                  'TrazaCafé es una app de GoProduction (Nicaragua) para la '
                  'trazabilidad del café y el cacao. Cada cooperativa, '
                  'exportadora o beneficio que la usa es responsable de los '
                  'datos de sus productores; GoProduction los procesa por '
                  'cuenta de ella (Ley 787 de Protección de Datos Personales).',
                ),
                titulo('Qué datos se recogen'),
                const Text(
                  '• Del equipo de la organización: correo de Google, nombre de '
                  'la cuenta y un identificador interno.\n'
                  '• De los productores: nombre, cédula (opcional), comunidad y '
                  'la foto del consentimiento firmado.\n'
                  '• De las fincas: ubicación exacta (punto o polígono), área, '
                  'fotos, visitas de verificación y entregas de café o cacao.',
                ),
                titulo('Para qué se usan'),
                const Text(
                  'Para demostrar que el café y el cacao vienen de fincas sin '
                  'deforestación, como exige el reglamento europeo (EUDR): '
                  'revisión satelital de cada finca, lotes, contenedores y el '
                  'paquete de documentos para el comprador.',
                ),
                titulo('Con quién se comparten'),
                const Text(
                  '• El comprador de un contenedor recibe la ubicación y el área '
                  'de las fincas de origen. El nombre del productor solo va si '
                  'la cooperativa lo incluye.\n'
                  '• En la blockchain pública (Optimism) solo se guardan códigos '
                  '(hashes) y resultados, nunca nombres, cédulas ni ubicaciones '
                  'exactas.\n'
                  '• Los datos se guardan en Google Cloud y Firebase (servidores '
                  'en Estados Unidos). No se venden ni se usan para publicidad.',
                ),
                titulo('Cuánto tiempo se guardan'),
                const Text(
                  'Mientras la organización use TrazaCafé. Lo que salió en una '
                  'exportación se guarda 5 años sin datos personales, como manda '
                  'el EUDR, y después se borra.',
                ),
                titulo('Tus derechos'),
                const Text(
                  'Puedes pedir ver, corregir o borrar tus datos. Habla con tu '
                  'cooperativa o usa la página de eliminación de datos:',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/eliminar-datos'),
                        builder: (_) => const EliminarDatosScreen(),
                      ),
                    ),
                    child: const Text('Eliminar mis datos'),
                  ),
                ),
                if (soporteEmail.isNotEmpty) ...[
                  titulo('Contacto'),
                  SelectableText(soporteEmail),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
