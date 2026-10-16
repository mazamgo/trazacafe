import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'finca_screen.dart' show fecha;

/// Temporadas de cosecha de la organización. Solo el administrador crea;
/// crear requiere señal (las temporadas viven en el servidor).
class TemporadasScreen extends ConsumerWidget {
  const TemporadasScreen({super.key});

  Future<void> _crear(BuildContext context, WidgetRef ref) async {
    final datos = await showDialog<(String, DateTime, DateTime)>(
      context: context,
      builder: (_) => const _DialogoTemporada(),
    );
    if (datos == null || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      await ref
          .read(apiProvider)
          .crearTemporada(datos.$1, iso(datos.$2), iso(datos.$3));
      await ref.read(syncServiceProvider).sincronizar();
      mensajero.showSnackBar(
        SnackBar(content: Text('Temporada ${datos.$1} creada.')),
      );
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temporadas = ref.watch(temporadasProvider).value ?? const [];
    final actual = ref.watch(temporadaActualProvider);
    final esAdmin = ref.watch(sesionProvider).value?.esAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Temporadas de cosecha')),
      body: temporadas.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no hay temporadas. Las entregas y visitas se guardan igual y se asignan '
                  'solas cuando el administrador crea la temporada que las contiene.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                for (final t in temporadas)
                  ListTile(
                    leading: Icon(
                      t.id == actual?.id ? Icons.today : Icons.event_note,
                    ),
                    title: Text(t.nombre),
                    subtitle: Text('${fecha(t.inicio)} – ${fecha(t.fin)}'),
                    trailing: t.id == actual?.id
                        ? const Chip(label: Text('Actual'))
                        : null,
                  ),
              ],
            ),
      floatingActionButton: esAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _crear(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Temporada'),
            )
          : null,
    );
  }
}

class _DialogoTemporada extends StatefulWidget {
  const _DialogoTemporada();

  @override
  State<_DialogoTemporada> createState() => _DialogoTemporadaState();
}

class _DialogoTemporadaState extends State<_DialogoTemporada> {
  late DateTime _inicio;
  late DateTime _fin;
  late final TextEditingController _nombre;

  @override
  void initState() {
    super.initState();
    // Propuesta: año cafetero (1 oct – 30 sep) que contiene hoy.
    final hoy = DateTime.now();
    final anio = hoy.month >= 10 ? hoy.year : hoy.year - 1;
    _inicio = DateTime(anio, 10, 1);
    _fin = DateTime(anio + 1, 9, 30);
    _nombre = TextEditingController(text: '$anio/${(anio + 1) % 100}');
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _elegir(bool inicio) async {
    final d = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fin,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (d != null) setState(() => inicio ? _inicio = d : _fin = d);
  }

  @override
  Widget build(BuildContext context) {
    final valido = _nombre.text.trim().isNotEmpty && _inicio.isBefore(_fin);
    return AlertDialog(
      title: const Text('Nueva temporada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'p. ej. 2026/27',
            ),
            onChanged: (_) => setState(() {}),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Inicio'),
            trailing: Text(fecha(_inicio)),
            onTap: () => _elegir(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fin'),
            trailing: Text(fecha(_fin)),
            onTap: () => _elegir(false),
          ),
          if (!_inicio.isBefore(_fin))
            Text(
              'El fin debe ser después del inicio.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: valido
              ? () =>
                    Navigator.pop(context, (_nombre.text.trim(), _inicio, _fin))
              : null,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
