import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/acceso.dart';
import '../services/auth_service.dart';

/// Se muestra después de entrar con Google y antes de tener acceso: activa la
/// invitación. Si el correo no está invitado, la sesión se cierra y el login
/// muestra el motivo.
class ActivacionScreen extends ConsumerStatefulWidget {
  const ActivacionScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ActivacionScreen> createState() => _ActivacionScreenState();
}

class _ActivacionScreenState extends ConsumerState<ActivacionScreen> {
  String? _error;
  bool _intentando = false;

  @override
  void initState() {
    super.initState();
    _activar();
  }

  Future<void> _activar() async {
    final aviso = ref.read(avisoAccesoProvider.notifier);
    setState(() {
      _intentando = true;
      _error = null;
    });
    try {
      await activar(ref.read(authServiceProvider), ref.read(apiProvider));
    } on AuthError catch (e) {
      // La sesión ya se cerró; el login mostrará el mensaje.
      aviso.mostrar(e.mensaje);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo verificar tu acceso: $e');
      }
    } finally {
      if (mounted) setState(() => _intentando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_intentando) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Verificando el acceso de ${widget.email}…',
                    textAlign: TextAlign.center,
                  ),
                ] else if (_error != null) ...[
                  Icon(
                    Icons.wifi_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _activar,
                    child: const Text('Reintentar'),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(authServiceProvider).cerrarSesion(),
                  child: const Text('Usar otra cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
