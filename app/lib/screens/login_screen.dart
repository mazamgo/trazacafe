import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _cargando = false;

  /// Después de Google, la app pasa sola a la pantalla de activación.
  Future<void> _entrar() async {
    final aviso = ref.read(avisoAccesoProvider.notifier);
    setState(() => _cargando = true);
    aviso.mostrar(null);
    try {
      await ref.read(authServiceProvider).entrarConGoogle();
    } on AuthCancelado {
      // La persona cerró el selector de cuentas.
    } catch (e) {
      aviso.mostrar(e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(avisoAccesoProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.coffee, size: 56),
                const SizedBox(height: 8),
                Text('TrazaCafé',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text('Acceso para técnicos y administradores', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _cargando ? null : _entrar,
                  icon: _cargando
                      ? const SizedBox.square(
                          dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.account_circle),
                  label: const Text('Entrar con Google'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(error,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                Text(
                  'Usa la cuenta de Google con la que te invitó tu organización.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
