import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cultivos.dart';
import '../providers.dart';

/// Cultivos con los que trabaja la organización (solo administradores;
/// guardar requiere señal). Con más de uno, Nueva finca pregunta el cultivo.
class CultivosScreen extends ConsumerStatefulWidget {
  const CultivosScreen({super.key});

  @override
  ConsumerState<CultivosScreen> createState() => _CultivosScreenState();
}

class _CultivosScreenState extends ConsumerState<CultivosScreen> {
  /// Selección en pantalla; `null` = todavía igual a la de la organización.
  Set<String>? _elegidos;
  bool _guardando = false;

  Future<void> _guardar(Set<String> elegidos) async {
    setState(() => _guardando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).actualizarCultivos([
        for (final c in todosLosCultivos)
          if (elegidos.contains(c.id)) c.id,
      ]);
      await ref.read(syncServiceProvider).sincronizar();
      mensajero.showSnackBar(
        const SnackBar(content: Text('Cultivos de la organización guardados.')),
      );
      if (mounted) setState(() => _elegidos = null);
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actuales = {
      ...ref.watch(cultivosOrganizacionProvider).value ??
          const [cultivoPorDefecto],
    };
    final elegidos = _elegidos ?? actuales;
    final cambio =
        elegidos.length != actuales.length || !elegidos.containsAll(actuales);

    return Scaffold(
      appBar: AppBar(title: const Text('Cultivos')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Marca los cultivos que acopia la organización. Cada finca se '
              'registra con uno de ellos y sus entregas usan los estados de ese '
              'cultivo. No se puede quitar un cultivo que ya tiene fincas.',
            ),
          ),
          for (final c in todosLosCultivos)
            CheckboxListTile(
              value: elegidos.contains(c.id),
              secondary: Icon(c.icono, color: c.colorUi),
              title: Text(c.nombre),
              subtitle: Text(
                'Entregas: ${c.estados.map((e) => e.corto.toLowerCase()).join(', ')}',
              ),
              onChanged: _guardando
                  ? null
                  : (marcado) => setState(() {
                      final nuevo = {...elegidos};
                      marcado == true ? nuevo.add(c.id) : nuevo.remove(c.id);
                      _elegidos = nuevo;
                    }),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: !cambio || elegidos.isEmpty || _guardando
                ? null
                : () => _guardar(elegidos),
            child: Text(
              elegidos.isEmpty ? 'Elige al menos un cultivo' : 'Guardar',
            ),
          ),
        ),
      ),
    );
  }
}
