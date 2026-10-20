import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/cultivos.dart';
import '../providers.dart';
import 'finca_screen.dart' show fecha;

/// Temporadas de cosecha de la organización. Solo el administrador crea;
/// crear requiere señal (las temporadas viven en el servidor). Una temporada
/// puede ser de un solo cultivo (p. ej. la cosecha de cacao) o de todos.
class TemporadasScreen extends ConsumerWidget {
  const TemporadasScreen({super.key});

  Future<void> _crear(BuildContext context, WidgetRef ref) async {
    final datos = await showDialog<(String, DateTime, DateTime, String?)>(
      context: context,
      builder: (_) => _DialogoTemporada(
        cultivos:
            ref.read(cultivosOrganizacionProvider).value ??
            const [cultivoPorDefecto],
      ),
    );
    if (datos == null || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      await ref
          .read(apiProvider)
          .crearTemporada(
            datos.$1,
            iso(datos.$2),
            iso(datos.$3),
            cultivo: datos.$4,
          );
      await ref.read(syncServiceProvider).sincronizar();
      mensajero.showSnackBar(
        SnackBar(content: Text('Temporada ${datos.$1} creada.')),
      );
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _corregir(
    BuildContext context,
    WidgetRef ref,
    Temporada t,
  ) async {
    final cambios = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _DialogoCorregirTemporada(temporada: t),
    );
    if (cambios == null || cambios.isEmpty || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final api = ref.read(apiProvider);
    try {
      if (cambios['eliminar'] == true) {
        await api.eliminarTemporada(t.id);
      } else {
        await api.corregirTemporada(t.id, cambios);
      }
      // Las entregas y visitas se reasignan en el servidor: se descargan.
      await ref.read(syncServiceProvider).sincronizar();
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            cambios['eliminar'] == true
                ? 'Temporada ${t.nombre} eliminada.'
                : 'Temporada corregida.',
          ),
        ),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo corregir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temporadas = ref.watch(temporadasProvider).value ?? const [];
    final hoy = DateTime.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    // Puede haber más de una vigente (una general y otra de cacao).
    bool vigente(Temporada t) => !dia.isBefore(t.inicio) && !dia.isAfter(t.fin);
    final variosCultivos =
        (ref.watch(cultivosOrganizacionProvider).value?.length ?? 1) > 1;
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
                    leading: t.cultivo == null
                        ? Icon(vigente(t) ? Icons.today : Icons.event_note)
                        : Icon(
                            cultivoDe(t.cultivo!).icono,
                            color: cultivoDe(t.cultivo!).colorUi,
                          ),
                    title: Text(t.nombre),
                    subtitle: Text(
                      '${fecha(t.inicio)} – ${fecha(t.fin)}'
                      '${t.cultivo != null
                          ? ' · solo ${cultivoDe(t.cultivo!).nombre.toLowerCase()}'
                          : variosCultivos
                          ? ' · todos los cultivos'
                          : ''}',
                    ),
                    trailing: vigente(t)
                        ? const Chip(label: Text('Actual'))
                        : null,
                    onTap: esAdmin ? () => _corregir(context, ref, t) : null,
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
  const _DialogoTemporada({required this.cultivos});

  /// Cultivos de la organización.
  final List<String> cultivos;

  @override
  State<_DialogoTemporada> createState() => _DialogoTemporadaState();
}

class _DialogoTemporadaState extends State<_DialogoTemporada> {
  late DateTime _inicio;
  late DateTime _fin;
  late final TextEditingController _nombre;

  /// `null` = todos los cultivos.
  String? _cultivo;

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
          if (widget.cultivos.length > 1)
            DropdownButtonFormField<String?>(
              initialValue: _cultivo,
              decoration: const InputDecoration(labelText: 'Cultivo'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos los cultivos'),
                ),
                for (final c in widget.cultivos.map(cultivoDe))
                  DropdownMenuItem(
                    value: c.id,
                    child: Text('Solo ${c.nombre}'),
                  ),
              ],
              onChanged: (c) => setState(() => _cultivo = c),
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
          if (_muyLarga(_inicio, _fin))
            const Text(
              'Dura más de 18 meses: revisa que el año sea el correcto.',
              style: TextStyle(color: Colors.orange),
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
              ? () => Navigator.pop(context, (
                  _nombre.text.trim(),
                  _inicio,
                  _fin,
                  _cultivo,
                ))
              : null,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Más de 18 meses suele ser un año mal elegido (2026 en vez de 2027).
bool _muyLarga(DateTime inicio, DateTime fin) =>
    fin.difference(inicio).inDays > 548;

/// Corrige nombre o fechas (con motivo) o elimina. Devuelve los cambios
/// para la API, o {'eliminar': true}.
class _DialogoCorregirTemporada extends StatefulWidget {
  const _DialogoCorregirTemporada({required this.temporada});

  final Temporada temporada;

  @override
  State<_DialogoCorregirTemporada> createState() =>
      _DialogoCorregirTemporadaState();
}

class _DialogoCorregirTemporadaState extends State<_DialogoCorregirTemporada> {
  late final _nombre = TextEditingController(text: widget.temporada.nombre);
  final _motivo = TextEditingController();
  late DateTime _inicio = widget.temporada.inicio;
  late DateTime _fin = widget.temporada.fin;
  String? _error;

  bool get _cambianFechas =>
      _inicio != widget.temporada.inicio || _fin != widget.temporada.fin;

  @override
  void dispose() {
    _nombre.dispose();
    _motivo.dispose();
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

  void _guardar() {
    if (_nombre.text.trim().isEmpty || !_inicio.isBefore(_fin)) {
      setState(
        () => _error = 'Revisa el nombre y que el fin sea después del inicio.',
      );
      return;
    }
    if (_cambianFechas && _motivo.text.trim().length < 3) {
      setState(() => _error = 'Escribe por qué cambias las fechas.');
      return;
    }
    Navigator.pop(context, <String, Object?>{
      if (_nombre.text.trim() != widget.temporada.nombre)
        'nombre': _nombre.text.trim(),
      if (_inicio != widget.temporada.inicio) 'inicio': _iso(_inicio),
      if (_fin != widget.temporada.fin) 'fin': _iso(_fin),
      if (_motivo.text.trim().isNotEmpty) 'motivo': _motivo.text.trim(),
    });
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar ${widget.temporada.nombre}?'),
        content: const Text(
          'Solo se puede si no tiene lotes. Sus entregas y visitas pasan a la '
          'temporada que les corresponda o quedan sin temporada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, <String, Object?>{'eliminar': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corregir temporada'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
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
            if (_muyLarga(_inicio, _fin))
              const Text(
                'Dura más de 18 meses: revisa que el año sea el correcto.',
                style: TextStyle(color: Colors.orange),
              ),
            if (_cambianFechas)
              TextField(
                controller: _motivo,
                decoration: const InputDecoration(
                  labelText: 'Motivo del cambio de fechas',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _eliminar,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Eliminar temporada',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
