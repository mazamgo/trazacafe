import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cedula.dart';
import '../providers.dart';
import '../services/auth_service.dart';
import '../services/eliminacion_service.dart';
import 'privacidad_publica_screen.dart';

/// Correo de soporte de GoProduction que muestran las páginas de eliminación
/// de datos y privacidad (vacío = no se muestra).
const soporteEmail = String.fromEnvironment(
  'SOPORTE_EMAIL',
  defaultValue: 'mauricio.zambrana.g@gmail.com',
);

/// Página pública `/eliminar-datos` (requisito de Google Play): se puede
/// pedir la eliminación sin instalar la app. El productor llena un
/// formulario; quien trabaja en una cooperativa entra con Google.
class EliminarDatosScreen extends StatelessWidget {
  const EliminarDatosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('TrazaCafé · Eliminar datos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Eliminar tus datos de TrazaCafé', style: t.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'TrazaCafé es la app de trazabilidad de café y cacao de '
                  'GoProduction (Nicaragua). Las cooperativas la usan para '
                  'registrar a sus productores y fincas y cumplir el reglamento '
                  'europeo contra la deforestación (EUDR). Aquí puedes pedir que '
                  'se borren tus datos sin instalar la app.',
                ),
                const SizedBox(height: 24),
                const _FormularioProductor(),
                const SizedBox(height: 16),
                const _CuentaDelEquipo(),
                const SizedBox(height: 24),
                const _QueSeConserva(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/privacidad'),
                          builder: (_) => const PrivacidadPublicaScreen(),
                        ),
                      ),
                      child: const Text('Política de privacidad'),
                    ),
                    if (soporteEmail.isNotEmpty)
                      SelectableText('Soporte: $soporteEmail'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.icono,
    required this.titulo,
    required this.hijos,
  });

  final IconData icono;
  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...hijos,
        ],
      ),
    ),
  );
}

/// El productor no tiene cuenta: su cooperativa registró sus datos y es
/// quien aprueba la eliminación.
class _FormularioProductor extends ConsumerStatefulWidget {
  const _FormularioProductor();

  @override
  ConsumerState<_FormularioProductor> createState() =>
      _FormularioProductorState();
}

class _FormularioProductorState extends ConsumerState<_FormularioProductor> {
  final _nombre = TextEditingController();
  final _cedula = TextEditingController();
  final _comunidad = TextEditingController();
  final _contacto = TextEditingController();
  final _mensaje = TextEditingController();
  // Campo trampa: no se ve; si llega con texto, lo llenó un bot.
  final _sitio = TextEditingController();
  late final Future<List<OrganizacionPublica>> _organizaciones = ref
      .read(eliminacionPublicaProvider)
      .organizaciones();

  /// `''` = "No sé o no aparece"; `null` = sin elegir.
  String? _organizacion;
  String? _error;
  bool _enviando = false;
  bool _enviada = false;

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _cedula,
      _comunidad,
      _contacto,
      _mensaje,
      _sitio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    final cedula = _cedula.text.trim();
    final error = switch (()) {
      _ when _organizacion == null => 'Elige tu cooperativa (o "No sé").',
      _ when _nombre.text.trim().length < 3 => 'Escribe tu nombre completo.',
      _ when cedula.isNotEmpty && normalizarCedula(cedula) == null =>
        'La cédula debe tener el formato 001-010190-0001A.',
      _ when _contacto.text.trim().length < 5 =>
        'Escribe un teléfono o correo para avisarte.',
      _ => null,
    };
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _enviando = true);
    try {
      String? opcional(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      await ref
          .read(eliminacionPublicaProvider)
          .pedirEliminacion(
            organizacionId: _organizacion!.isEmpty ? null : _organizacion,
            nombre: _nombre.text.trim(),
            contacto: _contacto.text.trim(),
            cedula: opcional(_cedula),
            comunidad: opcional(_comunidad),
            mensaje: opcional(_mensaje),
            sitio: _sitio.text,
          );
      setState(() => _enviada = true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enviada) {
      return const _Seccion(
        icono: Icons.mark_email_read_outlined,
        titulo: 'Recibimos tu solicitud',
        hijos: [
          Text(
            'Tu cooperativa la revisará y te avisará al teléfono o correo que '
            'dejaste, en un máximo de 30 días. Si no supiste cuál es tu '
            'cooperativa, GoProduction se comunicará contigo.',
          ),
        ],
      );
    }
    return _Seccion(
      icono: Icons.agriculture,
      titulo: 'Soy productor o productora',
      hijos: [
        const Text(
          'Tu cooperativa registró tus datos y tus fincas. Llena este '
          'formulario: tu cooperativa confirma que eres tú y los borra.',
        ),
        const SizedBox(height: 8),
        FutureBuilder(
          future: _organizaciones,
          builder: (context, snap) => DropdownButtonFormField<String>(
            initialValue: _organizacion,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Tu cooperativa',
              helperText: snap.hasError
                  ? 'No se pudo cargar la lista; elige "No sé".'
                  : null,
            ),
            items: [
              for (final o in snap.data ?? const <OrganizacionPublica>[])
                DropdownMenuItem(value: o.id, child: Text(o.nombre)),
              const DropdownMenuItem(
                value: '',
                child: Text('No sé o no aparece'),
              ),
            ],
            onChanged: (v) => setState(() => _organizacion = v),
          ),
        ),
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
        ),
        TextField(
          controller: _cedula,
          decoration: const InputDecoration(
            labelText: 'Cédula (opcional, ayuda a encontrarte)',
            hintText: '001-010190-0001A',
          ),
        ),
        TextField(
          controller: _comunidad,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Comunidad (opcional)'),
        ),
        TextField(
          controller: _contacto,
          decoration: const InputDecoration(
            labelText: 'Teléfono o correo para avisarte',
          ),
        ),
        TextField(
          controller: _mensaje,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Mensaje (opcional)'),
        ),
        Offstage(
          child: TextField(
            controller: _sitio,
            decoration: const InputDecoration(labelText: 'Sitio web'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Enviando…' : 'Pedir que borren mis datos'),
        ),
      ],
    );
  }
}

/// Técnicos y administradores: entran con Google y eliminan su cuenta (o el
/// administrador, la organización).
class _CuentaDelEquipo extends ConsumerStatefulWidget {
  const _CuentaDelEquipo();

  @override
  ConsumerState<_CuentaDelEquipo> createState() => _CuentaDelEquipoState();
}

class _CuentaDelEquipoState extends ConsumerState<_CuentaDelEquipo> {
  bool _trabajando = false;
  String? _mensaje;

  Future<void> _hacer(Future<String?> Function() f) async {
    setState(() {
      _trabajando = true;
      _mensaje = null;
    });
    try {
      final m = await f();
      if (mounted) setState(() => _mensaje = m);
    } on AuthCancelado {
      // Cerró el selector de cuentas.
    } catch (e) {
      if (mounted) setState(() => _mensaje = '$e');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<bool> _confirmar(String texto, String boton) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(texto),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(boton),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider).value;
    final auth = ref.read(authServiceProvider);
    return _Seccion(
      icono: Icons.badge_outlined,
      titulo: 'Trabajo en una cooperativa (técnico o administrador)',
      hijos: [
        const Text(
          'Entra con la cuenta de Google que usas en la app. Al eliminar tu '
          'cuenta pierdes el acceso; lo que registraste es de tu cooperativa y '
          'se queda con ella, sin tu nombre ni tu correo.',
        ),
        const SizedBox(height: 12),
        if (sesion == null)
          OutlinedButton.icon(
            onPressed: _trabajando
                ? null
                : () => _hacer(() async {
                    await auth.entrarConGoogle();
                    return null;
                  }),
            icon: const Icon(Icons.login),
            label: const Text('Entrar con Google'),
          )
        else ...[
          Text('Sesión: ${sesion.email}'),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _trabajando
                ? null
                : () => _hacer(() async {
                    if (!await _confirmar(
                      '¿Eliminar la cuenta ${sesion.email} de TrazaCafé? No se puede deshacer.',
                      'Eliminar mi cuenta',
                    )) {
                      return null;
                    }
                    await ref.read(apiProvider).eliminarCuenta();
                    await auth.cerrarSesion();
                    return 'Tu cuenta se eliminó.';
                  }),
            child: const Text('Eliminar mi cuenta'),
          ),
          if (sesion.esAdmin) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _trabajando
                  ? null
                  : () => _hacer(() async {
                      if (!await _confirmar(
                        'En 30 días se borran todos los datos de tu organización. '
                            'Puedes cancelarlo desde la app (Privacidad y datos).',
                        'Eliminar la organización',
                      )) {
                        return null;
                      }
                      final dia = await ref
                          .read(apiProvider)
                          .programarEliminacionOrganizacion();
                      return 'La organización se eliminará el '
                          '${dia.day}/${dia.month}/${dia.year}.';
                    }),
              child: const Text('Eliminar toda la organización'),
            ),
          ],
          TextButton(
            onPressed: _trabajando ? null : auth.cerrarSesion,
            child: const Text('Salir'),
          ),
        ],
        if (_mensaje != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_mensaje!),
          ),
      ],
    );
  }
}

/// Qué se borra, qué se conserva y por cuánto tiempo (lo pide Google Play).
class _QueSeConserva extends StatelessWidget {
  const _QueSeConserva();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget punto(String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(texto)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Qué se borra, qué se conserva y por cuánto tiempo',
          style: t.titleMedium,
        ),
        const SizedBox(height: 8),
        Text('Productores', style: t.titleSmall),
        punto(
          'Se borran tu nombre, cédula, comunidad, las fotos de tu '
          'consentimiento, de tus fincas y de las visitas, y las fincas que no '
          'se han vendido.',
        ),
        punto(
          'Si una finca tiene café o cacao que ya salió en un lote o contenedor '
          'de exportación, la ley europea (EUDR, art. 12) obliga a guardar 5 '
          'años su ubicación y sus entregas. Esos datos quedan sin tu nombre ni '
          'ningún otro dato personal y se borran solos al cumplir los 5 años.',
        ),
        punto(
          'En la blockchain solo hay códigos (hashes) que no permiten '
          'identificarte; no se pueden borrar, pero no contienen datos '
          'personales.',
        ),
        Text('Cuentas del equipo', style: t.titleSmall),
        punto(
          'Se borran tu cuenta de acceso y tu correo. Los registros que hiciste '
          'pertenecen a tu cooperativa y quedan con un código interno como autor.',
        ),
        Text('Organizaciones', style: t.titleSmall),
        punto(
          'Se borra todo 30 días después de pedirlo (se puede cancelar en ese '
          'plazo), salvo lo que el EUDR obliga a guardar, que queda sin datos '
          'personales 5 años.',
        ),
        Text('Plazos', style: t.titleSmall),
        punto(
          'Las solicitudes de productores se responden en un máximo de 30 días. '
          'Las fotos se borran del almacenamiento en un máximo de 2 días después '
          'de aprobada la eliminación.',
        ),
      ],
    );
  }
}
