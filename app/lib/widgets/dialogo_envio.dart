import 'package:flutter/material.dart';

import '../screens/finca_screen.dart' show fecha;

typedef Envio = ({String? destino, double kg, DateTime fecha});

/// Kg y fecha de un envío o de una recepción de lote; con [destinos], además
/// a quién (id → nombre). Devuelve `null` si se cancela.
Future<Envio?> pedirEnvio(
  BuildContext context, {
  required String titulo,
  required String etiquetaKg,
  required String etiquetaFecha,
  required String accion,
  required double kgInicial,
  Map<String, String>? destinos,
  String? explicacion,
}) => showDialog<Envio>(
  context: context,
  builder: (_) => _DialogoEnvio(
    titulo: titulo,
    etiquetaKg: etiquetaKg,
    etiquetaFecha: etiquetaFecha,
    accion: accion,
    kgInicial: kgInicial,
    destinos: destinos,
    explicacion: explicacion,
  ),
);

class _DialogoEnvio extends StatefulWidget {
  const _DialogoEnvio({
    required this.titulo,
    required this.etiquetaKg,
    required this.etiquetaFecha,
    required this.accion,
    required this.kgInicial,
    required this.destinos,
    required this.explicacion,
  });

  final String titulo;
  final String etiquetaKg;
  final String etiquetaFecha;
  final String accion;
  final double kgInicial;
  final Map<String, String>? destinos;
  final String? explicacion;

  @override
  State<_DialogoEnvio> createState() => _DialogoEnvioState();
}

class _DialogoEnvioState extends State<_DialogoEnvio> {
  late final _kg = TextEditingController(
    text: widget.kgInicial == widget.kgInicial.roundToDouble()
        ? widget.kgInicial.toInt().toString()
        : widget.kgInicial.toString(),
  );
  late String? _destino = widget.destinos?.keys.firstOrNull;
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  double? get _kgValido {
    final kg = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    return kg != null && kg > 0 ? kg : null;
  }

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _fecha = d);
  }

  @override
  Widget build(BuildContext context) {
    final kg = _kgValido;
    final listo = kg != null && (widget.destinos == null || _destino != null);
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.explicacion != null) Text(widget.explicacion!),
            if (widget.destinos case final destinos?)
              DropdownButtonFormField<String>(
                initialValue: _destino,
                decoration: const InputDecoration(labelText: 'Cliente'),
                items: [
                  for (final d in destinos.entries)
                    DropdownMenuItem(value: d.key, child: Text(d.value)),
                ],
                onChanged: (v) => setState(() => _destino = v),
              ),
            TextField(
              controller: _kg,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.etiquetaKg,
                suffixText: 'kg',
                errorText: kg == null ? 'Escribe los kg' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(widget.etiquetaFecha),
              subtitle: Text(fecha(_fecha)),
              onTap: _elegirFecha,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: listo
              ? () => Navigator.pop<Envio>(context, (
                  destino: _destino,
                  kg: kg,
                  fecha: _fecha,
                ))
              : null,
          child: Text(widget.accion),
        ),
      ],
    );
  }
}
