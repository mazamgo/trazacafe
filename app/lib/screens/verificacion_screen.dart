import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../domain/geo.dart';
import '../providers.dart';
import '../services/fotos_service.dart';
import 'nueva_finca_screen.dart';

/// Visita de verificación de una finca en la temporada: fotos nuevas
/// (obligatorias) y, si el lindero cambió, uno nuevo. Nada anterior se borra.
class VerificacionScreen extends ConsumerStatefulWidget {
  const VerificacionScreen({super.key, required this.finca});

  final Finca finca;

  @override
  ConsumerState<VerificacionScreen> createState() => _VerificacionScreenState();
}

class _VerificacionScreenState extends ConsumerState<VerificacionScreen> {
  final _id = const Uuid().v4();
  final _nota = TextEditingController();
  final _fotos = <FotoTomada>[];
  bool _linderoCambio = false;
  LinderoNuevo? _lindero;
  bool _guardando = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto() async {
    final foto = await ref.read(fotosServiceProvider).tomar();
    if (foto != null) setState(() => _fotos.add(foto));
  }

  Future<void> _dibujarLindero() async {
    final nuevo = await Navigator.of(context).push<LinderoNuevo>(
      MaterialPageRoute(
        builder: (_) => NuevaFincaScreen(
          linderoAnterior: desdeGeoJsonCoords(widget.finca.coordenadasJson),
        ),
      ),
    );
    if (nuevo != null) setState(() => _lindero = nuevo);
  }

  /// Lo que falta para poder guardar, o `null` si está completa.
  String? get _falta {
    if (_fotos.isEmpty) {
      return 'Toma al menos una foto de la finca en esta visita.';
    }
    if (_linderoCambio && _lindero == null) {
      return 'Dibuja el lindero nuevo o marca que no cambió.';
    }
    return null;
  }

  Future<void> _guardar() async {
    final falta = _falta;
    if (falta != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(falta)));
      return;
    }
    setState(() => _guardando = true);
    final nota = _nota.text.trim();
    await ref
        .read(databaseProvider)
        .guardarVisita(
          finca: widget.finca,
          visita: VerificacionesCompanion.insert(
            id: _id,
            fincaId: widget.finca.id,
            fecha: DateTime.now(),
            linderoCambio: Value(_linderoCambio),
            versionFinca: widget.finca.version,
            nota: Value(nota.isEmpty ? null : nota),
          ),
          fotosVisita: [
            for (final f in _fotos)
              FotosService.registro(
                f,
                entidadTipo: 'verificacion',
                entidadId: _id,
                tipo: 'verificacion',
              ),
          ],
          linderoNuevo: _linderoCambio ? _lindero : null,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visita guardada. Se enviará al sincronizar.'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final temporada = ref.watch(temporadaActualProvider);
    final falta = _falta;

    return Scaffold(
      appBar: AppBar(title: const Text('Visita de verificación')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            widget.finca.nombre,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            temporada == null
                ? 'Sin temporada actual: la visita se asignará cuando la organización la cree.'
                : 'Temporada ${temporada.nombre}',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Fotos de esta visita *',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _tomarFoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Tomar foto'),
              ),
            ],
          ),
          const Text(
            'Muestra cómo está hoy la finca: cultivo, bordes y zonas con árboles.',
          ),
          const SizedBox(height: 8),
          if (_fotos.isNotEmpty)
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _fotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_fotos[i].ruta),
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    cacheWidth: 176,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _linderoCambio,
            onChanged: (v) => setState(() => _linderoCambio = v),
            title: const Text('¿Cambió el lindero de la finca?'),
            subtitle: const Text(
              'Por ejemplo, compró o vendió una parte, o el mapa anterior estaba mal.',
            ),
          ),
          if (_linderoCambio)
            Card(
              child: ListTile(
                leading: Icon(
                  _lindero == null
                      ? Icons.edit_location_alt_outlined
                      : Icons.check_circle,
                  color: _lindero == null ? null : Colors.green,
                ),
                title: Text(
                  _lindero == null
                      ? 'Dibujar el lindero nuevo'
                      : 'Lindero nuevo: ${_lindero!.areaHa.toStringAsFixed(2)} ha',
                ),
                subtitle: Text(
                  'Quedará como versión ${widget.finca.sincronizado ? widget.finca.version + 1 : widget.finca.version}; '
                  'la anterior se conserva.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _dibujarLindero,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _nota,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              hintText: 'Lo que observaste: tala, quemas, ampliaciones…',
            ),
          ),
          const SizedBox(height: 8),
          if (falta != null)
            Text(
              falta,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _guardando || falta != null ? null : _guardar,
            child: const Text('Guardar visita'),
          ),
        ],
      ),
    );
  }
}
