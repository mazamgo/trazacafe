import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Antes de entrar a la app revisa de quién son los datos del celular (ver
/// `DatosCelular`). Si son de otra organización y ya se enviaron, se borran
/// solos; si quedan sin enviar, pregunta qué hacer.
class CelularListo extends ConsumerWidget {
  const CelularListo({
    super.key,
    required this.organizacionId,
    required this.child,
  });

  final String organizacionId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(celularListoProvider(organizacionId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo revisar los datos del celular: $e',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          data: (sinEnviar) => sinEnviar == 0
              ? child
              : CelularCompartidoScreen(
                  organizacionId: organizacionId,
                  sinEnviar: sinEnviar,
                ),
        );
  }
}

/// El celular tiene registros sin enviar de otra organización.
class CelularCompartidoScreen extends ConsumerStatefulWidget {
  const CelularCompartidoScreen({
    super.key,
    required this.organizacionId,
    required this.sinEnviar,
  });

  final String organizacionId;
  final int sinEnviar;

  @override
  ConsumerState<CelularCompartidoScreen> createState() =>
      _CelularCompartidoScreenState();
}

class _CelularCompartidoScreenState
    extends ConsumerState<CelularCompartidoScreen> {
  bool _borrando = false;

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar los datos sin enviar?'),
        content: Text(
          'Se borrarán del celular ${widget.sinEnviar} registros de la otra '
          'organización y sus fotos. No llegaron al servidor, así que no se '
          'pueden recuperar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _borrando = true);
    await ref.read(datosCelularProvider).borrarPara(widget.organizacionId);
    ref.invalidate(celularListoProvider(widget.organizacionId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de otra organización')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.phonelink_lock, size: 64),
          const SizedBox(height: 16),
          Text(
            'Este celular tiene ${widget.sinEnviar} registros sin enviar de '
            'otra organización.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Para no perderlos, la persona de esa organización debe entrar con '
            'su cuenta y tocar Sincronizar con señal. Después ya puedes '
            'entrar tú: el celular se limpia solo y se descargan los datos '
            'de tu organización.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _borrando
                ? null
                : () => ref.read(authServiceProvider).cerrarSesion(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _borrando ? null : _borrar,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Borrar esos datos y continuar'),
          ),
        ],
      ),
    );
  }
}
