import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../domain/cultivos.dart';
import '../providers.dart';
import '../services/auth_service.dart';
import '../widgets/en_linea.dart';
import 'finca_screen.dart' show fecha;
import 'login_screen.dart';

/// Lo que devuelve la consola (`/v1/consola/*`), como mapas: es una
/// herramienta interna de GoProduction y no pasa por la base del celular.
typedef Fila = Map<String, dynamic>;

final consolaOrganizacionesProvider = FutureProvider.autoDispose<List<Fila>>(
  (ref) async =>
      ((await ref
                  .watch(apiProvider)
                  .consola(
                    'GET',
                    '/v1/consola/organizaciones',
                  ))['organizaciones']
              as List)
          .cast<Fila>(),
);

final consolaUsoProvider = FutureProvider.autoDispose
    .family<List<Fila>, String>(
      (ref, mes) async =>
          ((await ref
                      .watch(apiProvider)
                      .consola('GET', '/v1/consola/uso?mes=$mes'))['uso']
                  as List)
              .cast<Fila>(),
    );

final consolaSaludProvider = FutureProvider.autoDispose<Fila>(
  (ref) => ref.watch(apiProvider).consola('GET', '/v1/consola/salud'),
);

final consolaSolicitudesProvider = FutureProvider.autoDispose<List<Fila>>(
  (ref) async =>
      ((await ref
                  .watch(apiProvider)
                  .consola('GET', '/v1/consola/solicitudes'))['solicitudes']
              as List)
          .cast<Fila>(),
);

final consolaEquipoProvider = FutureProvider.autoDispose
    .family<List<Fila>, String>(
      (ref, id) async =>
          ((await ref
                      .watch(apiProvider)
                      .consola(
                        'GET',
                        '/v1/consola/organizaciones/$id/equipo',
                      ))['equipo']
                  as List)
              .cast<Fila>(),
    );

const tiposOrganizacion = {
  'cooperativa': 'Cooperativa',
  'exportadora': 'Exportadora',
  'beneficio': 'Beneficio',
  'importador': 'Importador',
  'otra': 'Otra',
};

/// Consola del propietario en `/consola`: solo cuentas con el claim
/// `propietario` (se asigna con `npm run propietario`).
class ConsolaWeb extends ConsumerWidget {
  const ConsolaWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(sesionProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        data: (sesion) => switch (sesion) {
          null => const LoginScreen(),
          Sesion(propietario: false) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('La consola es solo para GoProduction.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(authServiceProvider).cerrarSesion(),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
          _ => ConsolaScreen(sesion: sesion),
        },
      );
}

class ConsolaScreen extends ConsumerStatefulWidget {
  const ConsolaScreen({super.key, required this.sesion});

  final Sesion sesion;

  @override
  ConsumerState<ConsolaScreen> createState() => _ConsolaScreenState();
}

class _ConsolaScreenState extends ConsumerState<ConsolaScreen> {
  int _i = 0;

  static const _secciones = [
    ('Organizaciones', Icons.apartment),
    ('Uso', Icons.receipt_long_outlined),
    ('Salud', Icons.monitor_heart_outlined),
    ('Solicitudes', Icons.mark_email_unread_outlined),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('TrazaCafé · Consola'),
      actions: [
        Center(child: Text(widget.sesion.email)),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () => ref.read(authServiceProvider).cerrarSesion(),
        ),
      ],
    ),
    body: Row(
      children: [
        NavigationRail(
          selectedIndex: _i,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (i) => setState(() => _i = i),
          destinations: [
            for (final (t, i) in _secciones)
              NavigationRailDestination(icon: Icon(i), label: Text(t)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: switch (_i) {
                0 => const _Organizaciones(),
                1 => const _Uso(),
                2 => const _Salud(),
                _ => const _Solicitudes(),
              },
            ),
          ),
        ),
      ],
    ),
  );
}

/// Lista con carga y Reintentar.
Widget _lista<T>(
  AsyncValue<T> v,
  WidgetRef ref,
  ProviderOrFamily p,
  Widget Function(T) cuerpo,
) => v.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => ErrorEnLinea(
    'No se pudo cargar: $e',
    onReintentar: () => ref.invalidate(p),
  ),
  data: cuerpo,
);

class _Organizaciones extends ConsumerWidget {
  const _Organizaciones();

  Future<void> _crear(BuildContext context, WidgetRef ref) async {
    final d = await showDialog<Fila>(
      context: context,
      builder: (_) => const _DialogoOrganizacion(),
    );
    if (d == null || !context.mounted) return;
    final hecho = await ejecutarEnLinea(
      context,
      () => ref
          .read(apiProvider)
          .consola('POST', '/v1/consola/organizaciones', d),
      'Organización ${d['nombre']} creada. Su administrador entra con ${d['admin']}.',
    );
    if (hecho) ref.invalidate(consolaOrganizacionesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _crear(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Organización'),
    ),
    body: _lista(
      ref.watch(consolaOrganizacionesProvider),
      ref,
      consolaOrganizacionesProvider,
      (orgs) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          for (final o in orgs)
            Card(
              child: ExpansionTile(
                leading: Icon(
                  o['suspendida'] == true ? Icons.block : Icons.apartment,
                  color: o['suspendida'] == true ? Colors.red : null,
                ),
                title: Text(
                  '${o['nombre']} · ${tiposOrganizacion[o['tipo']] ?? o['tipo']}',
                ),
                subtitle: Text(
                  [
                    '${o['productores']} productores',
                    '${o['fincas']} fincas, ${o['hectareas']} ha',
                    '${o['contenedoresCerrados']} contenedores cerrados',
                    'plan ${o['plan'] ?? '—'}${o['estadoContrato'] != null ? ' (${o['estadoContrato']})' : ''}',
                    if (o['suspendida'] == true) 'SUSPENDIDA',
                    if (o['eliminacionProgramada'] != null)
                      'eliminación programada',
                  ].join(' · '),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [_Detalle(o)],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Detalle extends ConsumerWidget {
  const _Detalle(this.o);

  final Fila o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = o['id'] as String;
    final api = ref.read(apiProvider);
    Future<void> hacer(Future<void> Function() f, String exito) async {
      final hecho = await ejecutarEnLinea(context, f, exito);
      if (hecho) {
        ref
          ..invalidate(consolaOrganizacionesProvider)
          ..invalidate(consolaEquipoProvider(id));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            DropdownButton<String>(
              value: o['tipo'] as String,
              items: [
                for (final e in tiposOrganizacion.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (t) => hacer(
                () => api.consola('PATCH', '/v1/consola/organizaciones/$id', {
                  'tipo': t,
                }),
                'Tipo cambiado.',
              ),
            ),
            OutlinedButton(
              onPressed: () => hacer(
                () => api.consola(
                  'POST',
                  '/v1/consola/organizaciones/$id/${o['suspendida'] == true ? 'reactivar' : 'suspender'}',
                  const <String, dynamic>{},
                ),
                o['suspendida'] == true
                    ? 'Organización reactivada.'
                    : 'Organización suspendida: no puede cargar datos nuevos.',
              ),
              child: Text(
                o['suspendida'] == true
                    ? 'Reactivar'
                    : 'Suspender por falta de pago',
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final email = await pedirTexto(
                  context,
                  titulo: 'Invitar al equipo',
                  etiqueta: 'Correo de Google',
                  accion: 'Invitar como técnico',
                );
                if (email == null) return;
                await hacer(
                  () => api.consola(
                    'POST',
                    '/v1/consola/organizaciones/$id/equipo',
                    {'email': email, 'rol': 'tecnico'},
                  ),
                  'Invitación creada.',
                );
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invitar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Equipo', style: Theme.of(context).textTheme.labelLarge),
        _lista(
          ref.watch(consolaEquipoProvider(id)),
          ref,
          consolaEquipoProvider(id),
          (equipo) => Column(
            children: [
              for (final m in equipo)
                ListTile(
                  dense: true,
                  title: Text(m['email'] as String),
                  subtitle: Text(
                    '${m['rol'] == 'admin' ? 'Administrador' : 'Técnico'}'
                    '${m['activo'] == true ? '' : ' · invitación sin aceptar'}',
                  ),
                  trailing: Wrap(
                    children: [
                      if (m['rol'] != 'admin')
                        TextButton(
                          onPressed: () => hacer(
                            () => api.consola(
                              'PUT',
                              '/v1/consola/organizaciones/$id/equipo/${Uri.encodeComponent(m['email'] as String)}',
                              {'rol': 'admin'},
                            ),
                            '${m['email']} ahora es administrador.',
                          ),
                          child: const Text('Nombrar administrador'),
                        ),
                      if (m['activo'] != true)
                        IconButton(
                          tooltip: 'Cancelar invitación',
                          icon: const Icon(Icons.close),
                          onPressed: () => hacer(
                            () => api.consola(
                              'DELETE',
                              '/v1/consola/organizaciones/$id/equipo/${Uri.encodeComponent(m['email'] as String)}',
                            ),
                            'Invitación cancelada.',
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogoOrganizacion extends StatefulWidget {
  const _DialogoOrganizacion();

  @override
  State<_DialogoOrganizacion> createState() => _DialogoOrganizacionState();
}

class _DialogoOrganizacionState extends State<_DialogoOrganizacion> {
  final _nombre = TextEditingController();
  final _admin = TextEditingController();
  String _tipo = 'cooperativa';
  final _cultivos = {'cafe'};

  @override
  void dispose() {
    _nombre.dispose();
    _admin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva organización'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final e in tiposOrganizacion.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (t) => setState(() => _tipo = t!),
          ),
          for (final c in todosLosCultivos)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _cultivos.contains(c.id),
              title: Text(c.nombre),
              onChanged: (v) => setState(
                () => v == true ? _cultivos.add(c.id) : _cultivos.remove(c.id),
              ),
            ),
          TextField(
            controller: _admin,
            decoration: const InputDecoration(
              labelText: 'Correo de Google del primer administrador',
            ),
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
        onPressed: () => Navigator.pop(context, {
          'nombre': _nombre.text.trim(),
          'tipo': _tipo,
          'cultivos': _cultivos.toList(),
          'admin': _admin.text.trim(),
        }),
        child: const Text('Crear'),
      ),
    ],
  );
}

class _Uso extends ConsumerStatefulWidget {
  const _Uso();

  @override
  ConsumerState<_Uso> createState() => _UsoState();
}

class _UsoState extends ConsumerState<_Uso> {
  late String _mes = () {
    final h = DateTime.now();
    return '${h.year}-${h.month.toString().padLeft(2, '0')}';
  }();

  @override
  Widget build(BuildContext context) {
    final meses = [
      for (var i = 0; i < 12; i++)
        () {
          final d = DateTime(DateTime.now().year, DateTime.now().month - i);
          return '${d.year}-${d.month.toString().padLeft(2, '0')}';
        }(),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        DropdownButton<String>(
          value: _mes,
          items: [
            for (final m in meses) DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (m) => setState(() => _mes = m!),
        ),
        _lista(
          ref.watch(consolaUsoProvider(_mes)),
          ref,
          consolaUsoProvider(_mes),
          (filas) => Column(
            children: [
              for (final u in filas)
                ListTile(
                  title: Text(u['nombre'] as String),
                  subtitle: Text(
                    '${u['productoresActivos']} productores activos · ${u['fincas']} fincas, ${u['hectareas']} ha · '
                    '${u['contenedoresMes']} contenedores cerrados'
                    '${u['quedanBolsa'] != null ? ' · quedan ${u['quedanBolsa']} en la bolsa' : ''}'
                    '${(u['sinContrato'] as int) > 0 ? ' · ${u['sinContrato']} sin contrato' : ''}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final mensajero = ScaffoldMessenger.of(context);
                      try {
                        final bytes = await ref
                            .read(apiProvider)
                            .descargarConsola(
                              '/v1/consola/organizaciones/${u['organizacionId']}/estado-de-cuenta?mes=$_mes',
                            );
                        await ref
                            .read(compartidorProvider)
                            .compartir(
                              nombre:
                                  'estado-de-cuenta-${u['nombre']}-$_mes.csv',
                              bytes: bytes,
                              tipo: 'text/csv',
                              asunto: 'Estado de cuenta $_mes',
                            );
                      } catch (e) {
                        mensajero.showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                    child: Text('US\$ ${u['totalUsd']} · CSV'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Salud extends ConsumerWidget {
  const _Salud();

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => _lista(ref.watch(consolaSaludProvider), ref, consolaSaludProvider, (s) {
    final a = s['attestations'] as Fila;
    final f = s['firma'] as Fila;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Tareas programadas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final t in (s['tareas'] as List).cast<Fila>())
          ListTile(
            leading: Icon(
              t['ok'] == null
                  ? Icons.help_outline
                  : t['ok'] == true
                  ? Icons.check_circle
                  : Icons.error,
              color: t['ok'] == false ? Colors.red : null,
            ),
            title: Text(t['tarea'] as String),
            subtitle: Text(
              t['ultima'] == null
                  ? 'Sin corridas registradas todavía'
                  : 'Última: ${fecha(DateTime.parse(t['ultima'] as String).toLocal())} · ${t['detalle']}',
            ),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.link),
          title: Text(
            'Attestations pendientes: ${a['pendientes']} (${a['conError']} con error)',
          ),
          subtitle: Text(
            a['masAntigua'] == null
                ? 'La cola está vacía.'
                : 'La más antigua: ${fecha(DateTime.parse(a['masAntigua'] as String).toLocal())}',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: Text(
            'Saldo de la clave de firma: ${f['saldoEth'] ?? '—'} ETH',
          ),
          subtitle: Text('Red: ${f['red'] ?? 'sin clave de firma'}'),
        ),
        const Divider(),
        Text('Fincas en rojo', style: Theme.of(context).textTheme.titleMedium),
        if ((s['fincasEnRojo'] as List).isEmpty) const Text('Ninguna.'),
        for (final r in (s['fincasEnRojo'] as List).cast<Fila>())
          Text('${r['organizacion']}: ${r['fincas']}'),
      ],
    );
  });
}

class _Solicitudes extends ConsumerWidget {
  const _Solicitudes();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _lista(
    ref.watch(consolaSolicitudesProvider),
    ref,
    consolaSolicitudesProvider,
    (lista) => lista.isEmpty
        ? const Center(
            child: Text('No hay solicitudes de eliminación por atender.'),
          )
        : ListView(
            children: [
              for (final s in lista)
                ListTile(
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: Text(
                    s['organizacion'] == null
                        ? 'Sin cooperativa ("No sé"): la atiende GoProduction'
                        : 'De ${s['organizacion']}: lleva ${s['dias']} días sin respuesta',
                  ),
                  subtitle: Text(
                    'Recibida el ${fecha(DateTime.parse(s['creadaEn'] as String).toLocal())}',
                  ),
                ),
            ],
          ),
  );
}
