import 'package:flutter/material.dart';

/// Color, ícono y texto de cada resultado del chequeo satelital.
const estadosSatelitales = {
  'verde': (
    Colors.green,
    Icons.check_circle,
    'Sin deforestación detectada después de 2020',
  ),
  'amarillo': (
    Colors.orange,
    Icons.error,
    'Posible pérdida de bosque pequeña: requiere revisión',
  ),
  'rojo': (
    Colors.red,
    Icons.dangerous,
    'Pérdida de bosque después de 2020: no apta para exportar',
  ),
};

/// Ícono y texto del chequeo satelital de una finca; `pendiente` (o
/// desconocido) en gris.
class EstadoSatelital extends StatelessWidget {
  const EstadoSatelital(this.resultado, {super.key});

  final String resultado;

  @override
  Widget build(BuildContext context) {
    final sat = estadosSatelitales[resultado];
    final color = sat?.$1 ?? Theme.of(context).colorScheme.outline;
    return Row(
      children: [
        Icon(sat?.$2 ?? Icons.satellite_alt_outlined, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            sat?.$3 ?? 'Sin revisión satelital todavía',
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}
