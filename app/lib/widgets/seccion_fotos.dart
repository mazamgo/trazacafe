import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import '../services/fotos_service.dart';

/// Fotos de un productor o una finca, con su estado y un botón para tomar
/// otra. Las fotos se suben solas a Cloud Storage al sincronizar.
class SeccionFotos extends ConsumerWidget {
  const SeccionFotos({
    super.key,
    required this.titulo,
    required this.entidadTipo,
    required this.entidadId,
    required this.tipo,
    this.textoBoton = 'Agregar foto',
    this.vacio = 'Sin fotos todavía.',
  });

  final String titulo;

  /// `productor` o `finca`.
  final String entidadTipo;
  final String entidadId;

  /// `consentimiento`, `finca` o `documento`: el tipo de las fotos nuevas.
  final String tipo;
  final String textoBoton;
  final String vacio;

  Future<void> _tomar(BuildContext context, WidgetRef ref) async {
    final foto = await ref.read(fotosServiceProvider).tomar();
    if (foto == null) return;
    final db = ref.read(databaseProvider);
    await db
        .into(db.fotos)
        .insert(
          FotosService.registro(
            foto,
            entidadTipo: entidadTipo,
            entidadId: entidadId,
            tipo: tipo,
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto guardada. Se subirá al sincronizar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotos =
        ref.watch(fotosProvider((entidadTipo, entidadId))).value ??
        const <Foto>[];
    final subidas = fotos.where((f) => f.subida).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => _tomar(context, ref),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(textoBoton),
              ),
            ],
          ),
          if (fotos.isEmpty)
            Text(vacio)
          else ...[
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _Miniatura(foto: fotos[i]),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subidas == fotos.length
                  ? 'Todas las fotos están guardadas en el servidor ✓'
                  : '${fotos.length - subidas} de ${fotos.length} se subirán al sincronizar',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.foto});

  final Foto foto;

  @override
  Widget build(BuildContext context) {
    final archivo = File(foto.ruta);
    final sinArchivo = Container(
      width: 88,
      height: 88,
      color: Colors.black12,
      child: const Icon(Icons.image_not_supported_outlined),
    );
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          // Si el archivo ya no está en el celular, ni se intenta abrir.
          child: archivo.existsSync()
              ? Image.file(
                  archivo,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  cacheWidth: 176,
                  errorBuilder: (_, _, _) => sinArchivo,
                )
              : sinArchivo,
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Tooltip(
            message: foto.subida ? 'Subida al servidor' : 'Pendiente de subir',
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.white,
              child: Icon(
                foto.subida ? Icons.cloud_done : Icons.cloud_upload,
                size: 15,
                color: foto.subida ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
