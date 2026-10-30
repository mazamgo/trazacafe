import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/api_client.dart';
import '../widgets/en_linea.dart';
import 'finca_screen.dart' show fecha;
import 'observaciones_screen.dart';

/// Cooperativa (solo administradores; requiere señal): las exportadoras que
/// la invitaron como proveedora. Al aceptar elige si comparte los nombres de
/// productores y fincas; los lotes se le venden desde Lotes.
class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  void _refrescar(WidgetRef ref) {
    ref.invalidate(clientesProvider);
    ref.invalidate(avisosRedProvider);
  }

  Future<void> _aceptar(BuildContext context, WidgetRef ref, Vinculo v) async {
    final nombres = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAceptar(cliente: v.organizacion),
    );
    if (nombres == null || !context.mounted) return;
    if (await ejecutarEnLinea(
      context,
      () => ref
          .read(apiProvider)
          .responderCliente(v.id, aceptar: true, comparteNombres: nombres),
      '${v.organizacion} ya es tu cliente. Véndele lotes desde Lotes.',
    )) {
      _refrescar(ref);
    }
  }

  Future<void> _rechazar(BuildContext context, WidgetRef ref, Vinculo v) async {
    if (await ejecutarEnLinea(
      context,
      () => ref.read(apiProvider).responderCliente(v.id, aceptar: false),
      'Invitación de ${v.organizacion} rechazada.',
    )) {
      _refrescar(ref);
    }
  }

  Future<void> _nombres(
    BuildContext context,
    WidgetRef ref,
    Vinculo v,
    bool comparte,
  ) async {
    if (await ejecutarEnLinea(
      context,
      () => ref.read(apiProvider).compartirNombres(v.id, comparte),
      comparte
          ? '${v.organizacion} verá los nombres de fincas y productores.'
          : '${v.organizacion} verá las fincas con un código, sin nombres.',
    )) {
      _refrescar(ref);
    }
  }

  Future<void> _terminar(BuildContext context, WidgetRef ref, Vinculo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Terminar el vínculo?'),
        content: Text(
          '${v.organizacion} ya no verá tus fincas nuevas ni podrás venderle lotes. '
          'Los lotes que ya recibió se quedan con ella (el EUDR obliga a guardarlos); '
          'los enviados sin recibir vuelven a tu lista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await ejecutarEnLinea(
      context,
      () => ref.read(apiProvider).terminarCliente(v.id),
      'Vínculo con ${v.organizacion} terminado.',
    )) {
      _refrescar(ref);
      ref.invalidate(lotesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientes = ref.watch(clientesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            tooltip: 'Observaciones',
            icon: const Icon(Icons.rate_review_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ObservacionesScreen()),
            ),
          ),
        ],
      ),
      body: clientes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorEnLinea(
          'No se pudieron cargar los clientes: $e',
          onReintentar: () => _refrescar(ref),
        ),
        data: (lista) => RefreshIndicator(
          onRefresh: () => ref.refresh(clientesProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Aquí aparecen las exportadoras que te invitan como proveedora. '
                    'Pídele a la exportadora que te invite con el correo con que '
                    'entras a TrazaCafé.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final v in lista)
                if (v.pendiente)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${v.organizacion} te invitó como proveedora',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text('El ${fecha(v.invitadoEn)}.'),
                          OverflowBar(
                            alignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _rechazar(context, ref, v),
                                child: const Text('Rechazar'),
                              ),
                              FilledButton(
                                onPressed: () => _aceptar(context, ref, v),
                                child: const Text('Aceptar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            v.activo
                                ? Icons.handshake_outlined
                                : Icons.link_off,
                          ),
                          title: Text(v.organizacion),
                          subtitle: Text(
                            v.activo
                                ? '${v.lotesRecibidos} ${v.lotesRecibidos == 1 ? 'lote recibido' : 'lotes recibidos'}'
                                      '${v.lotesEnviados > 0 ? ', ${v.lotesEnviados} por recibir' : ''}'
                                : v.estado == 'rechazado'
                                ? 'Invitación rechazada'
                                : 'Vínculo terminado',
                          ),
                          trailing: v.activo
                              ? IconButton(
                                  tooltip: 'Terminar vínculo',
                                  icon: const Icon(Icons.link_off),
                                  onPressed: () => _terminar(context, ref, v),
                                )
                              : null,
                        ),
                        if (v.activo)
                          SwitchListTile(
                            title: const Text('Compartir nombres'),
                            subtitle: const Text(
                              'Nombres de productores y fincas. Si no, la exportadora '
                              've cada finca con un código.',
                            ),
                            value: v.comparteNombres,
                            onChanged: (s) => _nombres(context, ref, v, s),
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explica qué se comparte y pregunta por los nombres. Devuelve si comparte
/// nombres, o `null` si se cancela.
class _DialogoAceptar extends StatefulWidget {
  const _DialogoAceptar({required this.cliente});
  final String cliente;

  @override
  State<_DialogoAceptar> createState() => _DialogoAceptarState();
}

class _DialogoAceptarState extends State<_DialogoAceptar> {
  bool _nombres = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Vender a ${widget.cliente}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'De los lotes que le vendas, ${widget.cliente} verá lo que pide el EUDR: '
            'ubicación y área de cada finca de origen, estado satelital, visitas de '
            'verificación y registros en la blockchain. No ve el resto de tus fincas '
            'ni puede corregir tus datos.',
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compartir nombres de productores y fincas'),
            subtitle: const Text(
              'Son datos personales (Ley 787): compártelos solo si los productores '
              'lo autorizaron. Puedes cambiarlo después.',
            ),
            value: _nombres,
            onChanged: (v) => setState(() => _nombres = v),
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
        onPressed: () => Navigator.pop(context, _nombres),
        child: const Text('Aceptar'),
      ),
    ],
  );
}
