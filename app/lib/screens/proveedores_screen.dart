import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/api_client.dart';
import '../widgets/dialogo_envio.dart';
import '../widgets/en_linea.dart';
import 'finca_screen.dart' show fecha;
import 'lotes_screen.dart' show kgTexto;
import 'observaciones_screen.dart';
import 'revision_proveedor_screen.dart';

/// Exportadora o beneficio (solo administradores; requiere señal): las
/// cooperativas que le venden, la invitación a una nueva y los lotes que le
/// enviaron y falta recibir.
class ProveedoresScreen extends ConsumerWidget {
  const ProveedoresScreen({super.key});

  void _refrescar(WidgetRef ref) {
    ref.invalidate(proveedoresProvider);
    ref.invalidate(avisosRedProvider);
  }

  Future<void> _invitar(BuildContext context, WidgetRef ref) async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoInvitar(),
    );
    if (email == null || !context.mounted) return;
    final ok = await ejecutarEnLinea(
      context,
      () => ref.read(apiProvider).invitarProveedor(email),
      'Invitación enviada. La cooperativa la acepta en ⋮ → Clientes.',
    );
    if (ok) _refrescar(ref);
  }

  Future<void> _terminar(BuildContext context, WidgetRef ref, Vinculo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          v.pendiente ? '¿Cancelar la invitación?' : '¿Terminar el vínculo?',
        ),
        content: Text(
          v.pendiente
              ? '${v.organizacion} ya no podrá aceptarla.'
              : '${v.organizacion} ya no podrá venderte lotes y dejarás de ver '
                    'la revisión de sus fincas. Los lotes ya recibidos se quedan contigo; '
                    'los enviados sin recibir vuelven a la cooperativa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(v.pendiente ? 'Cancelar invitación' : 'Terminar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await ejecutarEnLinea(
      context,
      () => ref.read(apiProvider).terminarProveedor(v.id),
      v.pendiente ? 'Invitación cancelada.' : 'Vínculo terminado.',
    )) {
      _refrescar(ref);
    }
  }

  Future<void> _recibir(
    BuildContext context,
    WidgetRef ref,
    LotePorRecibir l,
  ) async {
    final r = await pedirEnvio(
      context,
      titulo: 'Recibir ${l.codigo}',
      explicacion:
          '${l.proveedor} envió ${kgTexto(l.kgEnviados)} kg el ${fecha(l.fechaEnvio)}. '
          'Escribe lo que pesó al llegar: es lo que cuenta en el contenedor.',
      etiquetaKg: 'Kg recibidos',
      etiquetaFecha: 'Fecha de recepción',
      accion: 'Recibir',
      kgInicial: l.kgEnviados,
    );
    if (r == null || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final aviso = await ref
          .read(apiProvider)
          .recibirLote(l.id, kg: r.kg, fecha: r.fecha);
      _refrescar(ref);
      ref.invalidate(lotesProvider);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            aviso == null
                ? 'Lote ${l.codigo} recibido. Ya puedes ponerlo en un contenedor.'
                : 'Lote ${l.codigo} recibido. ${aviso.mensaje}',
          ),
        ),
      );
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo recibir: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(proveedoresProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proveedores'),
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
      body: datos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorEnLinea(
          'No se pudieron cargar los proveedores: $e',
          onReintentar: () => _refrescar(ref),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(proveedoresProvider.future),
          child: ListView(
            padding: EdgeInsets.only(
              bottom: 96 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (d.porRecibir.isNotEmpty) ...[
                const _Titulo('Lotes por recibir'),
                for (final l in d.porRecibir)
                  ListTile(
                    leading: Icon(
                      cultivoDe(l.cultivo).icono,
                      color: cultivoDe(l.cultivo).colorUi,
                    ),
                    title: Text('${l.codigo} · ${kgTexto(l.kgEnviados)} kg'),
                    subtitle: Text(
                      '${l.proveedor} · ${cultivoDe(l.cultivo).nombreEstado(l.estado).toLowerCase()} · '
                      '${l.temporadaNombre} · enviado el ${fecha(l.fechaEnvio)}',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => _recibir(context, ref, l),
                      child: const Text('Recibir'),
                    ),
                  ),
              ],
              const _Titulo('Cooperativas proveedoras'),
              if (d.proveedores.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Invita a las cooperativas que te venden. Ellas aceptan en su app y '
                    'te venden sus lotes: verás la ubicación, el área, el estado '
                    'satelital y las visitas de cada finca de origen.',
                  ),
                ),
              for (final v in d.proveedores)
                ListTile(
                  leading: Icon(
                    v.activo ? Icons.handshake_outlined : Icons.hourglass_empty,
                    color: v.activo ? null : Theme.of(context).disabledColor,
                  ),
                  title: Text(v.organizacion),
                  subtitle: Text(_estado(v)),
                  onTap: v.activo
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RevisionProveedorScreen(vinculo: v),
                          ),
                        )
                      : null,
                  trailing: v.activo || v.pendiente
                      ? IconButton(
                          tooltip: v.pendiente
                              ? 'Cancelar invitación'
                              : 'Terminar vínculo',
                          icon: const Icon(Icons.link_off),
                          onPressed: () => _terminar(context, ref, v),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _invitar(context, ref),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Invitar proveedor'),
      ),
    );
  }

  static String _estado(Vinculo v) => switch (v.estado) {
    'pendiente' =>
      'Invitación enviada el ${fecha(v.invitadoEn)}: falta que la acepte',
    'activo' =>
      '${v.lotesRecibidos} ${v.lotesRecibidos == 1 ? 'lote recibido' : 'lotes recibidos'}'
          '${v.lotesEnviados > 0 ? ', ${v.lotesEnviados} por recibir' : ''} · '
          '${v.comparteNombres ? 'comparte nombres' : 'fincas sin nombres'} · toca para revisar',
    'rechazado' => 'Rechazó la invitación',
    _ => 'Vínculo terminado',
  };
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _DialogoInvitar extends StatefulWidget {
  const _DialogoInvitar();

  @override
  State<_DialogoInvitar> createState() => _DialogoInvitarState();
}

class _DialogoInvitarState extends State<_DialogoInvitar> {
  final _email = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _aceptar() {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Escribe un correo válido.');
      return;
    }
    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invitar proveedor'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escribe el correo de Google con que entra a TrazaCafé el administrador '
          'de la cooperativa. Si la cooperativa todavía no usa TrazaCafé, '
          'escríbenos para darla de alta.',
        ),
        TextField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo del administrador',
            errorText: _error,
          ),
          onSubmitted: (_) => _aceptar(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _aceptar, child: const Text('Invitar')),
    ],
  );
}
