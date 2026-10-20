import 'package:flutter/material.dart';

import '../data/database.dart';
import '../domain/cultivos.dart';
import 'motivo.dart';

String _dos(int n) => n.toString().padLeft(2, '0');
String _fechaHora(DateTime f) =>
    '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';

/// 20000.5 → "20,000.5"; 500 → "500".
String kgLegible(double kg) {
  final texto = kg == kg.roundToDouble()
      ? kg.toStringAsFixed(0)
      : kg.toStringAsFixed(1);
  final partes = texto.split('.');
  final miles = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => ',',
  );
  return partes.length > 1 ? '$miles.${partes[1]}' : miles;
}

/// Lo que devuelve el formulario: guardar (nueva o corregida) o anular.
sealed class AccionEntrega {}

class GuardarEntrega extends AccionEntrega {
  GuardarEntrega(this.kg, this.estado, this.fecha, this.motivo);
  final double kg;
  final String estado;
  final DateTime fecha;

  /// Solo al corregir kg o fecha de una entrega ya enviada.
  final String? motivo;
}

class AnularEntrega extends AccionEntrega {
  AnularEntrega(this.motivo);
  final String motivo;
}

/// Formulario de una entrega: nueva o, con [inicial], corrección.
///
/// Antes de guardar muestra un resumen en letra grande ("Vas a registrar
/// 5,000 kg de uva en La Leonesa") con avisos si la cantidad es mayor de lo
/// que puede producir la finca en la temporada o si la fecha es antigua: así
/// se atrapan los ceros de más o de menos.
class FormularioEntrega extends StatefulWidget {
  const FormularioEntrega({
    super.key,
    required this.cultivo,
    required this.fincaNombre,
    this.inicial,
    this.areaHa,
    this.kgExportablesTemporada,
  });

  final Cultivo cultivo;
  final String fincaNombre;

  /// La entrega a corregir; `null` para una nueva.
  final Entrega? inicial;

  /// Área de la finca para el aviso de rendimiento (`null` si no se sabe).
  final double? areaHa;

  /// Kg exportables (café oro, cacao seco) que la finca ya entregó en la
  /// temporada de esa fecha, sin contar la entrega que se corrige.
  final double Function(DateTime fecha)? kgExportablesTemporada;

  @override
  State<FormularioEntrega> createState() => _FormularioEntregaState();
}

class _FormularioEntregaState extends State<FormularioEntrega> {
  late final _kg = TextEditingController(
    text: widget.inicial == null
        ? ''
        : kgLegible(widget.inicial!.kg).replaceAll(',', ''),
  );
  final _motivo = TextEditingController();
  late String _estado =
      widget.inicial?.estado ?? widget.cultivo.estados.first.id;
  late DateTime _fecha = widget.inicial?.fecha ?? DateTime.now();
  String? _error;
  String? _errorMotivo;

  bool get _corrigiendo => widget.inicial != null;

  /// La API pide motivo al cambiar kg o fecha de una entrega ya enviada.
  bool _pideMotivo(double kg) =>
      _corrigiendo &&
      widget.inicial!.sincronizado &&
      (kg != widget.inicial!.kg || _fecha != widget.inicial!.fecha);

  @override
  void dispose() {
    _kg.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    final elegido = DateTime(
      dia.year,
      dia.month,
      dia.day,
      hora?.hour ?? _fecha.hour,
      hora?.minute ?? _fecha.minute,
    );
    setState(() => _fecha = elegido.isAfter(hoy) ? hoy : elegido);
  }

  /// Avisos para el resumen: rendimiento por hectárea y fecha antigua.
  List<String> _avisos(double kg) {
    final avisos = <String>[];
    final area = widget.areaHa;
    final previas = widget.kgExportablesTemporada?.call(_fecha);
    if (area != null && area > 0 && previas != null) {
      final c = widget.cultivo;
      final exportable = c.estados.firstWhere((e) => e.factorExportable == 1);
      final total = previas + c.convertirKg(kg, _estado, exportable.id);
      final maximo = c.maxKgExportableHa * area;
      if (total > maximo) {
        avisos.add(
          'Con esta entrega, ${widget.fincaNombre} sumaría unos '
          '${kgLegible(total)} kg de ${exportable.nombre.toLowerCase()} en la temporada: '
          'más de lo que produce una finca de ${area.toStringAsFixed(2)} ha '
          '(máximo razonable ${kgLegible(maximo)} kg). ¿No sobra un cero?',
        );
      }
    }
    if (DateTime.now().difference(_fecha).inDays > 30) {
      avisos.add('La fecha es de hace más de 30 días.');
    }
    return avisos;
  }

  Future<bool> _confirmar(double kg) async {
    final avisos = _avisos(kg);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_corrigiendo ? '¿Corregir así?' : '¿Registrar así?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_corrigiendo ? 'Quedará en' : 'Vas a registrar'),
            Text(
              '${kgLegible(kg)} kg',
              style: Theme.of(c).textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'de ${widget.cultivo.nombreEstado(_estado).toLowerCase()} · '
              '${widget.fincaNombre} · ${_fechaHora(_fecha)}',
            ),
            for (final a in avisos)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sí, guardar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _guardar() async {
    final kg = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    if (kg == null || kg <= 0) {
      setState(() => _error = 'Escribe los kilos entregados.');
      return;
    }
    // Mismo límite que la API (cultivos.json).
    final maximo = widget.cultivo.maxKgEntrega;
    if (kg > maximo) {
      setState(
        () => _error =
            'Más de ${kgLegible(maximo.toDouble())} kg en una entrega parece un error.',
      );
      return;
    }
    final motivo = _motivo.text.trim();
    if (_pideMotivo(kg) && motivo.length < 3) {
      setState(() {
        _error = null;
        _errorMotivo = 'Escribe por qué corriges los kilos o la fecha.';
      });
      return;
    }
    setState(() => _error = _errorMotivo = null);
    // El resumen se muestra al registrar y al corregir los kilos.
    if (!_corrigiendo || kg != widget.inicial!.kg) {
      if (!await _confirmar(kg) || !mounted) return;
    }
    Navigator.pop(
      context,
      GuardarEntrega(kg, _estado, _fecha, motivo.isEmpty ? null : motivo),
    );
  }

  Future<void> _anular() async {
    final motivo = await pedirMotivo(
      context,
      titulo: 'Anular entrega',
      explicacion:
          'La entrega deja de contar (no irá a lotes ni al paquete EUDR). '
          'Queda en el historial con el motivo.',
      accion: 'Anular',
    );
    if (motivo != null && mounted) {
      Navigator.pop(context, AnularEntrega(motivo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final abajo =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;
    final enviada = widget.inicial?.sincronizado ?? false;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + abajo),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _corrigiendo
                  ? 'Corregir entrega'
                  : 'Nueva entrega de ${widget.cultivo.nombre.toLowerCase()}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_corrigiendo && enviada)
              Text(
                'Ya se envió: la corrección necesita señal y queda en el historial.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _kg,
              autofocus: !_corrigiendo,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Kilos entregados',
                suffixText: 'kg',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                for (final e in widget.cultivo.estados)
                  ButtonSegment(value: e.id, label: Text(e.corto)),
              ],
              selected: {_estado},
              onSelectionChanged: (s) => setState(() => _estado = s.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_fechaHora(_fecha)),
              subtitle: const Text('Fecha de la entrega'),
              onTap: _elegirFecha,
            ),
            if (_corrigiendo && enviada)
              TextField(
                controller: _motivo,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText:
                      'Motivo (obligatorio si cambian los kg o la fecha)',
                  hintText: 'p. ej. un cero de más',
                  errorText: _errorMotivo,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _guardar,
              child: Text(
                _corrigiendo ? 'Guardar corrección' : 'Guardar entrega',
              ),
            ),
            if (_corrigiendo)
              TextButton.icon(
                onPressed: _anular,
                icon: const Icon(Icons.block, color: Colors.red),
                label: const Text(
                  'Anular entrega',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
