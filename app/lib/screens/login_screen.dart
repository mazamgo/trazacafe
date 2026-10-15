import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await accion();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _entrar() {
    if (_correo.text.trim().isEmpty || _clave.text.isEmpty) {
      setState(() => _error = 'Escribe tu correo y contraseña.');
      return;
    }
    _ejecutar(() => ref.read(authServiceProvider).iniciarSesion(_correo.text.trim(), _clave.text));
  }

  void _recuperar() {
    if (_correo.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu correo para enviarte el enlace.');
      return;
    }
    _ejecutar(() async {
      await ref.read(authServiceProvider).recuperarClave(_correo.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te enviamos un enlace para cambiar la contraseña.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('Acceso para técnicos de campo', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                TextField(
                  controller: _clave,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  onSubmitted: (_) => _entrar(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _cargando ? null : _entrar,
                  child: _cargando
                      ? const SizedBox.square(
                          dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Entrar'),
                ),
                TextButton(
                  onPressed: _cargando ? null : _recuperar,
                  child: const Text('Olvidé mi contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
