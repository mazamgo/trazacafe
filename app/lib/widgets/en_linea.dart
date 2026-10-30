import 'package:flutter/material.dart';

/// Error al cargar algo que vive en la API (normalmente, falta de señal),
/// con el botón Reintentar.
class ErrorEnLinea extends StatelessWidget {
  const ErrorEnLinea(this.mensaje, {super.key, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mensaje, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onReintentar,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

/// Ejecuta [accion] y avisa en un SnackBar el [exito] o el error.
/// Devuelve `true` si salió bien.
Future<bool> ejecutarEnLinea(
  BuildContext context,
  Future<void> Function() accion,
  String exito,
) async {
  final mensajero = ScaffoldMessenger.of(context);
  try {
    await accion();
    mensajero.showSnackBar(SnackBar(content: Text(exito)));
    return true;
  } catch (e) {
    mensajero.showSnackBar(SnackBar(content: Text('$e')));
    return false;
  }
}

/// Pide un texto libre (observación, respuesta). `null` si se cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  required String accion,
  String? explicacion,
  int minimo = 3,
}) => showDialog<String>(
  context: context,
  builder: (_) => _DialogoTexto(
    titulo: titulo,
    etiqueta: etiqueta,
    accion: accion,
    explicacion: explicacion,
    minimo: minimo,
  ),
);

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.etiqueta,
    required this.accion,
    required this.explicacion,
    required this.minimo,
  });

  final String titulo;
  final String etiqueta;
  final String accion;
  final String? explicacion;
  final int minimo;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valido = _texto.text.trim().length >= widget.minimo;
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.explicacion != null) Text(widget.explicacion!),
          TextField(
            controller: _texto,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: widget.etiqueta),
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
              ? () => Navigator.pop(context, _texto.text.trim())
              : null,
          child: Text(widget.accion),
        ),
      ],
    );
  }
}
