import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/api_client.dart';
import '../widgets/en_linea.dart';
import '../widgets/estado_satelital.dart';
import '../widgets/mapa_fincas.dart';
import 'finca_screen.dart' show fecha;
import 'lotes_screen.dart' show kgTexto;

/// Cómo va la temporada (solo administradores; requiere señal): visitas,
/// estado satelital, alertas, kg por cultivo y lotes, y el CSV para Excel.
class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  String? _temporadaId;

  /// La elegida, o la vigente hoy, o la más reciente.
  Temporada? _temporada(List<Temporada> temporadas) =>
      temporadas.where((t) => t.id == _temporadaId).firstOrNull ??
      temporadaVigente(temporadas, DateTime.now()) ??
      temporadas.firstOrNull;

  Future<void> _csv(Temporada t) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(apiProvider).reporteCsv(t.id);
      await ref
          .read(compartidorProvider)
          .compartir(
            nombre: 'Reporte-${t.nombre.replaceAll('/', '-')}.csv',
            bytes: bytes,
            tipo: 'text/csv',
            asunto: 'Reporte de la temporada ${t.nombre}',
          );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo descargar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final temporadas = ref.watch(temporadasProvider).value ?? const [];
    final t = _temporada(temporadas);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          if (t != null)
            IconButton(
              tooltip: 'Descargar CSV',
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _csv(t),
            ),
        ],
      ),
      body: t == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay temporadas. Crea la de la cosecha en Temporadas.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ref
                .watch(reporteProvider(t.id))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorEnLinea(
                    'No se pudo cargar el reporte: $e',
                    onReintentar: () => ref.invalidate(reporteProvider(t.id)),
                  ),
                  data: (r) => RefreshIndicator(
                    onRefresh: () => ref.refresh(reporteProvider(t.id).future),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        12,
                        12,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: t.id,
                          key: ValueKey('temporada-${t.id}'),
                          decoration: const InputDecoration(
                            labelText: 'Temporada',
                          ),
                          items: [
                            for (final x in temporadas)
                              DropdownMenuItem(
                                value: x.id,
                                child: Text(
                                  x.cultivo == null
                                      ? x.nombre
                                      : '${x.nombre} · ${cultivoDe(x.cultivo!).nombre}',
                                ),
                              ),
                          ],
                          onChanged: (id) => setState(() => _temporadaId = id),
                        ),
                        const SizedBox(height: 12),
                        _Resumen(r.resumen),
                        _Satelite(r),
                        _Alertas(r, temporadaId: t.id),
                        _Visitas(r),
                        _Kg(r),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Las cifras de arriba, en tarjetas que se acomodan al ancho.
class _Resumen extends StatelessWidget {
  const _Resumen(this.r);

  final ResumenReporte r;

  @override
  Widget build(BuildContext context) {
    Widget tarjeta(String valor, String etiqueta) => SizedBox(
      width: 168,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor, style: Theme.of(context).textTheme.headlineSmall),
              Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        tarjeta('${r.productores}', 'productores'),
        tarjeta('${r.fincas}', 'fincas · ${r.areaOficialHa} ha'),
        tarjeta('${r.porcentajeVisita} %', 'con visita (${r.conVisita})'),
        tarjeta('${r.porcentajeVerde} %', 'en verde (${r.verdes})'),
        tarjeta('${kgTexto(r.kgEntregados)} kg', '${r.entregas} entregas'),
      ],
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.etiqueta,
    required this.valor,
    required this.total,
    this.color,
  });

  final String etiqueta;
  final int valor;
  final int total;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(etiqueta)),
        Expanded(
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : valor / total,
            color: color,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        SizedBox(width: 48, child: Text('$valor', textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _Satelite extends StatelessWidget {
  const _Satelite(this.r);

  final Reporte r;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Titulo('Estado satelital'),
      for (final (estado, etiqueta) in const [
        ('verde', 'Verde'),
        ('amarillo', 'Amarillo'),
        ('rojo', 'Rojo'),
        ('pendiente', 'Sin chequeo'),
      ])
        _Barra(
          etiqueta: etiqueta,
          valor: r.satelite[estado] ?? 0,
          total: r.resumen.fincas,
          color: estadosSatelitales[estado]?.$1 ?? Colors.grey,
        ),
    ],
  );
}

class _Alertas extends ConsumerWidget {
  const _Alertas(this.r, {required this.temporadaId});

  final Reporte r;
  final String temporadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Titulo('Alertas satelitales (${r.alertas.length})'),
      if (r.alertas.isEmpty)
        const Text('Todas las fincas están en verde.')
      else ...[
        MapaFincas(
          fincas: [
            for (final f in r.alertas)
              (
                nombre: f.nombre,
                puntos: f.puntos,
                deforestacion: f.deforestacion,
              ),
          ],
        ),
        for (final f in r.alertas)
          Card(
            child: ListTile(
              leading: Icon(
                estadosSatelitales[f.deforestacion]?.$2 ?? Icons.help_outline,
                color: estadosSatelitales[f.deforestacion]?.$1 ?? Colors.grey,
              ),
              title: Text('${f.nombre} · ${f.productorNombre}'),
              subtitle: Text(
                [
                  [
                    if (f.comunidad != null) f.comunidad!,
                    '${f.areaOficialHa} ha',
                  ].join(' · '),
                  f.ultimoChequeo == null
                      ? 'Sin chequeo satelital todavía'
                      : 'Chequeo del ${fecha(f.ultimoChequeo!)}'
                            '${f.fuente != null ? ' (${f.fuente})' : ''}'
                            '${(f.areaAfectadaHa ?? 0) > 0 ? ' · ${f.areaAfectadaHa} ha afectadas' : ''}',
                  if (!f.conVisita) 'Sin visita en la temporada',
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () async {
                  final hecho = await ejecutarEnLinea(
                    context,
                    () => ref.read(apiProvider).chequearFinca(f.id),
                    'Revisada ${f.nombre}.',
                  );
                  if (hecho) ref.invalidate(reporteProvider(temporadaId));
                },
                child: const Text('Revisar ahora'),
              ),
            ),
          ),
      ],
    ],
  );
}

class _Visitas extends StatelessWidget {
  const _Visitas(this.r);

  final Reporte r;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Titulo('Avance de visitas'),
      _Barra(
        etiqueta: 'Fincas visitadas',
        valor: r.resumen.conVisita,
        total: r.resumen.fincas,
      ),
      Text(
        '${r.resumen.conVisita} de ${r.resumen.fincas} fincas tienen la visita '
        'de verificación de ${r.temporadaNombre}.',
      ),
      if (r.visitas.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Por persona', style: Theme.of(context).textTheme.labelLarge),
        for (final v in r.visitas)
          Text(
            '${v.email ?? 'Ya no está en el equipo'}: ${v.visitas} '
            '${v.visitas == 1 ? 'visita' : 'visitas'}',
          ),
      ],
      const SizedBox(height: 8),
      Text(
        r.sinVisita.isEmpty
            ? 'Todas las fincas tienen visita.'
            : 'Fincas sin visita (${r.sinVisita.length})',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      for (final f in r.sinVisita)
        Text(
          '${f.nombre} · ${f.productorNombre}'
          '${f.comunidad != null ? ' · ${f.comunidad}' : ''}',
        ),
    ],
  );
}

class _Kg extends StatelessWidget {
  const _Kg(this.r);

  final Reporte r;

  @override
  Widget build(BuildContext context) {
    final l = r.lotes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Titulo('Kg de la temporada'),
        if (r.kg.isEmpty) const Text('Todavía no hay entregas.'),
        for (final k in r.kg)
          Builder(
            builder: (_) {
              final c = cultivoDe(k.cultivo);
              return Card(
                child: ListTile(
                  title: Text(
                    '${c.nombre} ${c.nombreEstado(k.estado).toLowerCase()}: '
                    '${kgTexto(k.kg)} kg',
                  ),
                  subtitle: Text(
                    'Rinden unos ${kgTexto(k.kgExportables)} kg de '
                    '${c.nombreEstado(k.estadoExportable).toLowerCase()} · '
                    '${k.entregas} ${k.entregas == 1 ? 'entrega' : 'entregas'}\n'
                    'En lotes: ${kgTexto(k.kgEnLotes)} kg · libres: ${kgTexto(k.kgLibres)} kg',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        Text(
          'Lotes: ${l.cerrados} cerrados y ${l.abiertos} abiertos; '
          '${l.vendidos} vendidos y ${l.enContenedor} en contenedores.',
        ),
      ],
    );
  }
}
