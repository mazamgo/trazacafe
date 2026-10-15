import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../providers.dart';
import '../services/fotos_service.dart';

/// Registro de un productor. Exige la foto del consentimiento firmado
/// (Ley 787) antes de guardar.
class NuevoProductorScreen extends ConsumerStatefulWidget {
  const NuevoProductorScreen({super.key});

  @override
  ConsumerState<NuevoProductorScreen> createState() =>
      _NuevoProductorScreenState();
}

class _NuevoProductorScreenState extends ConsumerState<NuevoProductorScreen> {
  final _nombre = TextEditingController();
  final _cedula = TextEditingController();
  final _comunidad = TextEditingController();
  FotoTomada? _consentimiento;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _cedula.dispose();
    _comunidad.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto() async {
    final foto = await ref.read(fotosServiceProvider).tomar();
    if (foto != null) setState(() => _consentimiento = foto);
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      _aviso('Escribe el nombre del productor.');
      return;
    }
    if (_consentimiento == null) {
      _aviso('Toma la foto del consentimiento firmado (Ley 787).');
      return;
    }
    setState(() => _guardando = true);
    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    String? opcional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    await db.transaction(() async {
      await db
          .into(db.productores)
          .insert(
            ProductoresCompanion.insert(
              id: id,
              nombre: _nombre.text.trim(),
              cedula: Value(opcional(_cedula)),
              comunidad: Value(opcional(_comunidad)),
              consentimientoFirmado: const Value(true),
            ),
          );
      await db
          .into(db.fotos)
          .insert(
            FotosService.registro(
              _consentimiento!,
              entidadTipo: 'productor',
              entidadId: id,
              tipo: 'consentimiento',
            ),
          );
    });
    if (mounted) Navigator.of(context).pop();
  }

  void _aviso(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo productor')),
      body: ListView(
        // Con padding propio, ListView ya no suma el espacio de la barra de
        // navegación del sistema; se agrega a mano para que el botón no quede debajo.
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre completo *'),
          ),
          TextField(
            controller: _cedula,
            decoration: const InputDecoration(labelText: 'Cédula (opcional)'),
          ),
          TextField(
            controller: _comunidad,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Comunidad (opcional)',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Consentimiento de datos *',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Foto del formulario firmado por el productor. Sus datos '
            'personales no se publican en la blockchain.',
          ),
          const SizedBox(height: 12),
          if (_consentimiento != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_consentimiento!.ruta),
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          OutlinedButton.icon(
            onPressed: _tomarFoto,
            icon: const Icon(Icons.photo_camera),
            label: Text(
              _consentimiento == null ? 'Tomar foto' : 'Repetir foto',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: const Text('Guardar productor'),
          ),
        ],
      ),
    );
  }
}
