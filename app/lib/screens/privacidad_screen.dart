import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';
import '../services/eliminacion_service.dart';
import 'finca_screen.dart' show fecha;
import 'solicitudes_eliminacion_screen.dart';

/// Menú ⋮ → Privacidad y datos: eliminar la propia cuenta y, para el
/// administrador, las solicitudes de productores y la eliminación de la
/// organización (requisito de Google Play y Ley 787).
class PrivacidadScreen extends ConsumerStatefulWidget {
  const PrivacidadScreen({super.key});

  @override
  ConsumerState<PrivacidadScreen> createState() => _PrivacidadScreenState();
}

class _PrivacidadScreenState extends ConsumerState<PrivacidadScreen> {
  bool _trabajando = false;

  Future<void> _hacer(Future<void> Function() accion, String listo) async {
    setState(() => _trabajando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await accion();
      mensajero.showSnackBar(SnackBar(content: Text(listo)));
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<bool> _confirmar(String titulo, String texto, String boton) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: Text(titulo),
          content: SingleChildScrollView(child: Text(texto)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error,
                foregroundColor: Theme.of(c).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(c, true),
              child: Text(boton),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _eliminarCuenta() async {
    final sesion = ref.read(sesionProvider).value;
    if (!await _confirmar(
      '¿Eliminar tu cuenta?',
      'Se borra tu cuenta de TrazaCafé (${sesion?.email ?? ''}) y pierdes el '
          'acceso a la organización. Este celular queda sin datos.\n\n'
          'Lo que registraste (productores, fincas, entregas) es de la '
          'organización y se queda con ella; solo guarda un código interno '
          'como autor, no tu nombre ni tu correo.\n\n'
          'Antes de borrar se envía lo que esté pendiente.',
      'Eliminar mi cuenta',
    )) {
      return;
    }
    setState(() => _trabajando = true);
    final servicio = ref.read(eliminacionServiceProvider);
    try {
      try {
        await servicio.eliminarMiCuenta();
      } on PendientesSinEnviar catch (e) {
        if (!mounted) return;
        final descartar = await _confirmar(
          'Hay datos sin enviar',
          '${e.total} registros de este celular no se pudieron enviar. Si '
              'eliminas la cuenta ahora, se pierden. Busca señal y vuelve a '
              'intentarlo, o elimínala de todos modos.',
          'Eliminar y perderlos',
        );
        if (!descartar) return;
        await servicio.eliminarMiCuenta(descartarPendientes: true);
      }
      // Sin sesión, la pantalla de inicio muestra el login.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _avisar('No se pudo eliminar la cuenta: $e');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  void _avisar(String texto) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));
    }
  }

  Future<void> _programarOrganizacion() async {
    if (!await _confirmar(
      '¿Eliminar la organización?',
      'En 30 días se borran todos los datos de la organización: equipo, '
          'productores, fincas, entregas, lotes y fotos. Hasta entonces '
          'puedes cancelarlo aquí.\n\n'
          'Lo que el EUDR obliga a guardar (fincas con entregas en lotes o '
          'contenedores) queda sin datos personales 5 años y después se '
          'borra solo.',
      'Eliminar en 30 días',
    )) {
      return;
    }
    await _hacer(
      ref.read(eliminacionServiceProvider).programarEliminacionOrganizacion,
      'Eliminación programada. Puedes cancelarla en los próximos 30 días.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(sesionProvider).value?.esAdmin ?? false;
    final pendientes = ref.watch(solicitudesPendientesProvider).value ?? 0;
    final programada = ref.watch(eliminacionProgramadaProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y datos')),
      body: AbsorbPointer(
        absorbing: _trabajando,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (_trabajando) const LinearProgressIndicator(),
            if (esAdmin) ...[
              const _Titulo('Organización'),
              ListTile(
                leading: Badge(
                  isLabelVisible: pendientes > 0,
                  label: Text('$pendientes'),
                  child: const Icon(Icons.mark_email_unread_outlined),
                ),
                title: const Text('Solicitudes de eliminación'),
                subtitle: Text(
                  pendientes == 0
                      ? 'Productores que piden borrar sus datos desde la página web.'
                      : '$pendientes sin responder. Respóndelas en menos de 30 días.',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SolicitudesEliminacionScreen(),
                  ),
                ),
              ),
              if (programada == null)
                ListTile(
                  leading: Icon(
                    Icons.domain_disabled_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('Eliminar la organización'),
                  subtitle: const Text(
                    'Borra todo después de 30 días; se puede cancelar.',
                  ),
                  onTap: _programarOrganizacion,
                )
              else
                ListTile(
                  leading: Icon(
                    Icons.event_busy,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text('Se eliminará el ${fecha(programada)}'),
                  subtitle: const Text(
                    'Hasta entonces la app funciona igual. Descarga lo que '
                    'necesites (lotes, paquetes EUDR) antes de esa fecha.',
                  ),
                  trailing: TextButton(
                    onPressed: () => _hacer(
                      ref
                          .read(eliminacionServiceProvider)
                          .cancelarEliminacionOrganizacion,
                      'Eliminación cancelada.',
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
            ],
            const _Titulo('Tu cuenta'),
            ListTile(
              leading: Icon(
                Icons.person_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Eliminar mi cuenta'),
              subtitle: const Text(
                'Borra tu cuenta y los datos de este celular.',
              ),
              onTap: _eliminarCuenta,
            ),
            const _Titulo('Más información'),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Página de eliminación de datos'),
              subtitle: Text(enlaceEliminarDatos),
              onTap: () => launchUrl(
                Uri.parse(enlaceEliminarDatos),
                mode: LaunchMode.externalApplication,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Política de privacidad'),
              onTap: () => launchUrl(
                Uri.parse(enlacePrivacidad),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
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
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
