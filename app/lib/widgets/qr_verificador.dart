import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers.dart';
import '../services/verificador_service.dart' show enlaceVerificador;

/// QR que lleva a la página pública del verificador, para un contenedor o un
/// lote ya firmado: para la etiqueta o para enviarlo al comprador.
class DialogoQr extends ConsumerWidget {
  const DialogoQr({
    super.key,
    required this.uid,
    required this.titulo,
    required this.archivo,
  });

  /// Attestation del contenedor o del lote.
  final String uid;

  /// "Contenedor CSQU3054383" o "Lote CAFE-2026/27-001".
  final String titulo;

  /// Base del nombre del PNG (número de contenedor o código del lote).
  final String archivo;

  Future<void> _compartir(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final imagen = await pngQr(
        enlaceVerificador(uid),
        '$titulo · verificar origen',
      );
      final nombre = archivo.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      await ref
          .read(compartidorProvider)
          .compartir(
            nombre: 'QR-$nombre.png',
            bytes: imagen,
            tipo: 'image/png',
            asunto: 'Verificar origen: ${titulo.toLowerCase()}',
          );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo compartir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enlace = enlaceVerificador(uid);
    return AlertDialog(
      title: Text(titulo),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Blanco también en tema oscuro: los lectores de QR lo necesitan.
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(data: enlace, size: 240),
            ),
            const SizedBox(height: 12),
            const Text(
              'El comprador lo escanea con la cámara y ve de qué fincas viene, '
              'sin datos personales, y su registro en la blockchain.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              enlace,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: enlace));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar enlace'),
        ),
        FilledButton.icon(
          onPressed: () => _compartir(context, ref),
          icon: const Icon(Icons.share),
          label: const Text('Compartir QR'),
        ),
      ],
    );
  }
}

/// PNG del QR sobre fondo blanco, con un texto debajo, listo para imprimir
/// en la etiqueta o mandar por WhatsApp.
Future<Uint8List> pngQr(String datos, String pie) async {
  const lado = 960.0, margen = 64.0, alto = lado + 2 * margen + 72;
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  lienzo.drawRect(
    const Rect.fromLTWH(0, 0, lado + 2 * margen, alto),
    Paint()..color = Colors.white,
  );
  lienzo.save();
  lienzo.translate(margen, margen);
  QrPainter(
    data: datos,
    version: QrVersions.auto,
    gapless: true,
  ).paint(lienzo, const Size.square(lado));
  lienzo.restore();
  final texto = TextPainter(
    text: TextSpan(
      text: pie,
      style: const TextStyle(color: Colors.black, fontSize: 40),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: lado);
  texto.paint(
    lienzo,
    Offset(margen + (lado - texto.width) / 2, margen + lado + 16),
  );
  final imagen = await grabadora.endRecording().toImage(
    (lado + 2 * margen).toInt(),
    alto.toInt(),
  );
  final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
