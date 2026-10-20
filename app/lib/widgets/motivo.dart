import 'package:flutter/material.dart';

/// Pide el motivo de una corrección o anulación (mínimo 3 letras, como la
/// API). Devuelve `null` si se cancela.
Future<String?> pedirMotivo(
  BuildContext context, {
  required String titulo,
  String? explicacion,
  String accion = 'Confirmar',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _DialogoMotivo(titulo: titulo, explicacion: explicacion, accion: accion),
);

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({
    required this.titulo,
    required this.explicacion,
    required this.accion,
  });

  final String titulo;
  final String? explicacion;
  final String accion;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valido = _motivo.text.trim().length >= 3;
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.explicacion != null) Text(widget.explicacion!),
          TextField(
            controller: _motivo,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'p. ej. registrada dos veces',
            ),
            onChanged: (_) => setState(() {}),
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
              ? () => Navigator.pop(context, _motivo.text.trim())
              : null,
          child: Text(widget.accion),
        ),
      ],
    );
  }
}
