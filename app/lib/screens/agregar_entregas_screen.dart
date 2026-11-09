import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/api_client.dart';
import '../widgets/lista_entregas.dart';
import 'lotes_screen.dart' show kgTexto;

/// Suma entregas libres a un lote abierto y pide su peso total nuevo. Devuelve
/// el [Lote] actualizado con `Navigator.pop`. Las reglas las aplica la API.
class AgregarEntregasScreen extends ConsumerStatefulWidget {
  const AgregarEntregasScreen({super.key, required this.lote});

  final Lote lote;

  @override
  ConsumerState<AgregarEntregasScreen> createState() =>
      _AgregarEntregasScreenState();
}

class _AgregarEntregasScreenState extends ConsumerState<AgregarEntregasScreen> {
  late final Future<List<EntregaDisponible>> _disponibles = ref
      .read(apiProvider)
      .entregasDisponibles(widget.lote.cultivo, widget.lote.temporadaId);
  final _elegidas = <String>{};
  final _kg = TextEditingController();

  /// Mientras la persona no escriba el peso, se propone el actual más lo
  /// que rinden las entregas elegidas.
  bool _kgEditado = false;
  bool _guardando = false;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  double _nuevos(List<EntregaDisponible> entregas) {
    final c = cultivoDe(widget.lote.cultivo);
    return entregas
        .where((e) => _elegidas.contains(e.id))
        .fold(
          0.0,
          (s, e) => s + c.convertirKg(e.kg, e.estado, widget.lote.estado),
        );
  }

  Future<void> _guardar() async {
    final kg = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    final mensajero = ScaffoldMessenger.of(context);
    if (kg == null || kg <= 0) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('Escribe el peso total del lote.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final lote = await ref
          .read(apiProvider)
          .agregarEntregas(
            widget.lote.id,
            entregas: _elegidas.toList(),
            kg: kg,
          );
      if (mounted) Navigator.of(context).pop(lote);
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudieron agregar: $e')),
      );
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lote = widget.lote;
    return Scaffold(
      appBar: AppBar(title: Text('Agregar a ${lote.codigo}')),
      body: FutureBuilder<List<EntregaDisponible>>(
        future: _disponibles,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('No se pudieron cargar las entregas: ${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _contenido(snap.data!);
        },
      ),
    );
  }

  Widget _contenido(List<EntregaDisponible> todas) {
    final lote = widget.lote;
    final c = cultivoDe(lote.cultivo);
    // Las que ya van en este lote no son opción ni error.
    final entregas = [
      for (final e in todas)
        if (e.motivo != 'Ya está en el lote ${lote.codigo}') e,
    ];
    final nuevos = _nuevos(entregas);
    final esperados = lote.kgEsperados + nuevos;
    final kg = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    final excede = kg != null && kg > esperados * (1 + toleranciaVolumen);
    final nombreEstado = c.nombreEstado(lote.estado).toLowerCase();

    void cambiar(void Function() f) => setState(() {
      f();
      if (!_kgEditado) {
        _kg.text = _elegidas.isEmpty
            ? ''
            : (lote.kg + _nuevos(entregas)).round().toString();
      }
    });

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          'Hoy pesa ${kgTexto(lote.kg)} kg de $nombreEstado, '
          'con ${lote.entregas.length} ${lote.entregas.length == 1 ? 'entrega' : 'entregas'}.',
        ),
        const SizedBox(height: 12),
        ListaEntregas(
          cultivo: c,
          entregas: entregas,
          elegidas: _elegidas,
          cambiar: cambiar,
        ),
        const Divider(height: 24),
        Text(
          _elegidas.isEmpty
              ? 'Elige las entregas que quieres sumar.'
              : 'Con ${_elegidas.length == 1 ? 'esta entrega' : 'estas ${_elegidas.length} entregas'}, '
                    'el lote debería rendir unos ${kgTexto(esperados)} kg de $nombreEstado.',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _kg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Peso total del lote en la báscula',
            suffixText: 'kg',
            helperText: excede
                ? 'Pesa más de lo que rinden sus entregas: se guardará con un aviso.'
                : null,
            helperStyle: const TextStyle(color: Colors.orange),
          ),
          onChanged: (_) => setState(() => _kgEditado = true),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _elegidas.isEmpty || _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Agregar al lote'),
        ),
      ],
    );
  }
}
