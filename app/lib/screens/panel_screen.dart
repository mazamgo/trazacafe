import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/avisos_red.dart';
import 'activacion_screen.dart';
import 'clientes_screen.dart';
import 'contenedores_screen.dart';
import 'equipo_screen.dart';
import 'login_screen.dart';
import 'lotes_screen.dart';
import 'observaciones_screen.dart';
import 'proveedores_screen.dart';

/// Panel web para administradores (`/panel`): las pantallas de la app que
/// trabajan con la API, en la computadora. Login → activación → panel; los
/// técnicos ven un aviso, porque su trabajo es en el campo con la app.
class PanelWeb extends ConsumerWidget {
  const PanelWeb({super.key, this.seccion});

  /// Sección de la URL (`/panel/contenedores`); `null` = la primera.
  final String? seccion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(sesionProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (sesion) => switch (sesion) {
            null => const LoginScreen(),
            Sesion(activa: false) => ActivacionScreen(email: sesion.email),
            Sesion(esAdmin: false) => _SoloAdministradores(sesion: sesion),
            _ => PanelScreen(sesion: sesion, seccion: seccion),
          },
        );
  }
}

class _SoloAdministradores extends ConsumerWidget {
  const _SoloAdministradores({required this.sesion});

  final Sesion sesion;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android, size: 48),
            const SizedBox(height: 16),
            Text(
              'El panel web es para administradores. Los técnicos trabajan '
              'con la app Android.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(sesion.email),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(authServiceProvider).cerrarSesion(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Cada cuánto el panel vuelve a pedir los avisos de la red.
const avisosCada = Duration(minutes: 3);

/// Una sección del menú del panel.
class SeccionPanel {
  const SeccionPanel(this.id, this.titulo, this.icono, this.pantalla);

  final String id;
  final String titulo;
  final IconData icono;
  final Widget pantalla;
}

/// Secciones según el tipo de organización: Proveedores para quien compra
/// lotes (exportadora, beneficio) y Clientes para quien los vende.
List<SeccionPanel> seccionesPanel(String? tipo) => [
  const SeccionPanel(
    'lotes',
    'Lotes',
    Icons.inventory_2_outlined,
    LotesScreen(),
  ),
  const SeccionPanel(
    'contenedores',
    'Contenedores',
    Icons.local_shipping_outlined,
    ContenedoresScreen(),
  ),
  if (tiposCliente.contains(tipo))
    const SeccionPanel(
      'proveedores',
      'Proveedores',
      Icons.storefront_outlined,
      ProveedoresScreen(),
    ),
  if (tiposProveedora.contains(tipo))
    const SeccionPanel(
      'clientes',
      'Clientes',
      Icons.handshake_outlined,
      ClientesScreen(),
    ),
  const SeccionPanel(
    'observaciones',
    'Observaciones',
    Icons.chat_outlined,
    ObservacionesScreen(),
  ),
  const SeccionPanel('equipo', 'Equipo', Icons.group_outlined, EquipoScreen()),
];

/// Menú a la izquierda (abajo en pantallas angostas) y la sección elegida
/// con su propio `Navigator`, para que lo que abre (revisión de un proveedor,
/// nuevo lote) quede dentro del panel con el menú a la vista.
class PanelScreen extends ConsumerStatefulWidget {
  const PanelScreen({super.key, required this.sesion, this.seccion});

  final Sesion sesion;
  final String? seccion;

  @override
  ConsumerState<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends ConsumerState<PanelScreen> {
  late String? _seccion = widget.seccion;

  void _abrir(String id) {
    setState(() => _seccion = id);
    // La URL sigue a la sección, para guardarla o recargar sin perderse.
    if (kIsWeb) {
      SystemNavigator.routeInformationUpdated(
        uri: Uri(path: '/panel/$id'),
        replace: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizacion = ref.watch(organizacionWebProvider);
    final tipo = ref.watch(tipoOrganizacionProvider);
    final red = ref.watch(avisosRedProvider).value;
    final secciones = seccionesPanel(tipo.value);
    final i = secciones.indexWhere((s) => s.id == _seccion);
    final actual = secciones[i < 0 ? 0 : i];
    final ancho = MediaQuery.sizeOf(context).width >= 720;

    return AvisosAlDia(
      cada: avisosCada,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            [
              'TrazaCafé',
              if (organizacion.value?['nombre'] case final String nombre)
                nombre,
              if (tipo.value case final String t) nombreTipoOrganizacion(t),
            ].join(' · '),
          ),
          actions: [
            if (ancho)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(widget.sesion.email),
                ),
              ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authServiceProvider).cerrarSesion(),
            ),
          ],
        ),
        body: tipo.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (tipo.hasError)
                    MaterialBanner(
                      leading: const Icon(Icons.cloud_off),
                      content: const Text(
                        'No se pudo leer la organización. Revisa la conexión.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(organizacionWebProvider),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  if (red != null && !red.vacio)
                    BannerRed(avisos: red, abrir: _abrir),
                  Expanded(
                    child: Row(
                      children: [
                        if (ancho) ...[
                          NavigationRail(
                            selectedIndex: secciones.indexOf(actual),
                            labelType: NavigationRailLabelType.all,
                            onDestinationSelected: (n) =>
                                _abrir(secciones[n].id),
                            destinations: [
                              for (final s in secciones)
                                NavigationRailDestination(
                                  icon: Icon(s.icono),
                                  label: Text(s.titulo),
                                ),
                            ],
                          ),
                          const VerticalDivider(width: 1),
                        ],
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1000),
                              child: Navigator(
                                key: ValueKey(actual.id),
                                onGenerateRoute: (_) => MaterialPageRoute(
                                  builder: (_) => actual.pantalla,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: ancho || tipo.isLoading
            ? null
            : NavigationBar(
                selectedIndex: secciones.indexOf(actual),
                onDestinationSelected: (n) => _abrir(secciones[n].id),
                destinations: [
                  for (final s in secciones)
                    NavigationDestination(icon: Icon(s.icono), label: s.titulo),
                ],
              ),
      ),
    );
  }
}
