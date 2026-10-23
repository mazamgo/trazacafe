import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/api_client.dart';
import 'lotes_screen.dart' show kgTexto;

/// Arma un contenedor con lotes libres de un mismo cultivo. Devuelve la
/// [Exportacion] creada con `Navigator.pop`.
class NuevoContenedorScreen extends ConsumerStatefulWidget {
  const NuevoContenedorScreen({super.key});

  @override
  ConsumerState<NuevoContenedorScreen> createState() =>
      _NuevoContenedorScreenState();
}

class _NuevoContenedorScreenState extends ConsumerState<NuevoContenedorScreen> {
  final _elegidos = <String>{};
  final _codigo = TextEditingController();
  final _comprador = TextEditingController();
  final _destino = TextEditingController();
  final _contenedor = TextEditingController();
  bool _codigoPuesto = false;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_codigo, _comprador, _destino, _contenedor]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "EXP-2026-003": año y número de contenedor de la organización.
  void _sugerirCodigo() {
    if (_codigoPuesto) return;
    _codigoPuesto = true;
    final n = (ref.read(exportacionesProvider).value ?? const []).length + 1;
    _codigo.text = 'EXP-${DateTime.now().year}-${n.toString().padLeft(3, '0')}';
  }

  Future<void> _guardar() async {
    final mensajero = ScaffoldMessenger.of(context);
    if ([_codigo, _comprador, _destino].any((c) => c.text.trim().isEmpty)) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('Escribe el código, el comprador y el destino.'),
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final x = await ref
          .read(apiProvider)
          .crearExportacion(
            codigo: _codigo.text.trim(),
            comprador: _comprador.text.trim(),
            destino: _destino.text.trim(),
            lotes: _elegidos.toList(),
            contenedor: _contenedor.text.trim().isEmpty
                ? null
                : _contenedor.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(x);
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo crear el contenedor: $e')),
      );
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lotes = ref.watch(lotesProvider);
    ref.watch(exportacionesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo contenedor')),
      body: lotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('No se pudieron cargar los lotes: $e')),
        data: (todos) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_codigoPuesto) setState(_sugerirCodigo);
          });
          final libres = [
            for (final l in todos)
              if (l.exportacionCodigo == null) l,
          ];
          final elegidos = [
            for (final l in libres)
              if (_elegidos.contains(l.id)) l,
          ];
          // El cultivo lo fija el primer lote elegido.
          final cultivo = elegidos.firstOrNull?.cultivo;
          final kg = elegidos.fold(0.0, (s, l) => s + l.kg);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Text(
                'Lotes libres (${libres.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (libres.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No hay lotes libres. Arma primero los lotes en ⋮ → Lotes.',
                  ),
                ),
              for (final l in libres)
                Builder(
                  builder: (_) {
                    final c = cultivoDe(l.cultivo);
                    final otroCultivo = cultivo != null && l.cultivo != cultivo;
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _elegidos.contains(l.id),
                      onChanged: otroCultivo
                          ? null
                          : (v) => setState(
                              () => v == true
                                  ? _elegidos.add(l.id)
                                  : _elegidos.remove(l.id),
                            ),
                      secondary: Icon(c.icono, color: c.colorUi),
                      title: Text('${l.codigo} · ${kgTexto(l.kg)} kg'),
                      subtitle: Text(
                        otroCultivo
                            ? 'Es de ${c.nombre.toLowerCase()}: un contenedor lleva un solo cultivo'
                            : '${c.nombre} ${c.nombreEstado(l.estado).toLowerCase()} · ${l.temporadaNombre}',
                      ),
                    );
                  },
                ),
              const Divider(height: 24),
              Text(
                elegidos.isEmpty
                    ? 'Elige los lotes del contenedor.'
                    : '${elegidos.length} ${elegidos.length == 1 ? 'lote' : 'lotes'} · ${kgTexto(kg)} kg',
              ),
              TextField(
                controller: _codigo,
                decoration: const InputDecoration(labelText: 'Código interno'),
              ),
              TextField(
                controller: _comprador,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Comprador'),
              ),
              TextField(
                controller: _destino,
                decoration: const InputDecoration(
                  labelText: 'Destino',
                  hintText: 'p. ej. Hamburgo, Alemania',
                ),
              ),
              TextField(
                controller: _contenedor,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Número de contenedor (opcional)',
                  hintText: 'p. ej. MSCU1234566',
                  helperText: 'Si todavía no lo tienes, lo agregas después.',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _elegidos.isEmpty || _guardando ? null : _guardar,
                child: Text(_guardando ? 'Guardando…' : 'Crear contenedor'),
              ),
            ],
          );
        },
      ),
    );
  }
}
