import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../screens/clientes_screen.dart';
import '../screens/lotes_screen.dart';
import '../screens/observaciones_screen.dart';
import '../screens/proveedores_screen.dart';
import '../screens/reportes_screen.dart';
import '../services/mensajeria.dart';

/// Pantalla que abre un aviso push.
Widget? pantallaDeAviso(String? pantalla) => switch (pantalla) {
  'clientes' => const ClientesScreen(),
  'proveedores' => const ProveedoresScreen(),
  'observaciones' => const ObservacionesScreen(),
  'lotes' => const LotesScreen(),
  'reportes' => const ReportesScreen(),
  _ => null,
};

/// Notificaciones push para administradores en el celular: registra el
/// token en la API, muestra los avisos que llegan con la app abierta y, al
/// tocar uno, abre su pantalla. Los técnicos no reciben avisos.
class AvisosPush extends ConsumerStatefulWidget {
  const AvisosPush({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AvisosPush> createState() => _AvisosPushState();
}

class _AvisosPushState extends ConsumerState<AvisosPush> {
  final _suscripciones = <StreamSubscription<Object>>[];
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mensajeria = ref.read(mensajeriaProvider);
    final esAdmin = ref.read(sesionProvider).value?.esAdmin ?? false;
    if (_iniciado || mensajeria == null || !esAdmin) return;
    _iniciado = true;
    unawaited(_iniciar(mensajeria));
  }

  Future<void> _registrar(String token) async {
    try {
      await ref.read(apiProvider).registrarDispositivo(token);
    } catch (_) {
      // Sin señal: se registra la próxima vez que se abra la app.
    }
  }

  void _abrir(String? pantalla) {
    final destino = pantallaDeAviso(pantalla);
    if (destino == null || !mounted) return;
    unawaited(
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => destino)),
    );
  }

  Future<void> _iniciar(Mensajeria m) async {
    try {
      if (!await m.pedirPermiso()) return;
      _suscripciones
        ..add(m.tokens.listen(_registrar))
        ..add(m.abiertos.listen((a) => _abrir(a.pantalla)))
        ..add(
          m.enPrimerPlano.listen((a) {
            ref.invalidate(avisosRedProvider);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  [a.titulo, a.cuerpo].whereType<String>().join(': '),
                ),
                action: a.pantalla == null
                    ? null
                    : SnackBarAction(
                        label: 'Ver',
                        onPressed: () => _abrir(a.pantalla),
                      ),
              ),
            );
          }),
        );
      await m.registrarse();
      final inicial = await m.inicial();
      if (inicial != null) _abrir(inicial.pantalla);
    } catch (_) {
      // Sin Google Play Services o sin señal: la app sigue sin avisos push.
    }
  }

  @override
  void dispose() {
    for (final s in _suscripciones) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
