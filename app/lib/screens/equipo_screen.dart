import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/api_client.dart';

/// Solo administradores: invitar y quitar personas de la organización.
/// Requiere señal (las invitaciones viven en la API).
class EquipoScreen extends ConsumerWidget {
  const EquipoScreen({super.key});

  static const _roles = {'tecnico': 'Técnico', 'admin': 'Administrador'};

  Future<void> _invitar(BuildContext context, WidgetRef ref) async {
    final datos = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _DialogoInvitar(),
    );
    if (datos == null || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref.read(apiProvider).invitar(datos.$1, datos.$2),
      'Invitación enviada a ${datos.$1}. Debe entrar con "Entrar con Google".',
    );
  }

  Future<void> _quitar(
    BuildContext context,
    WidgetRef ref,
    Invitacion inv,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Quitar acceso?'),
        content: Text(
          '${inv.email} ya no podrá entrar ni sincronizar. '
          'Lo que registró se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Quitar acceso'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref.read(apiProvider).quitarAcceso(inv.email),
      'Se quitó el acceso a ${inv.email}.',
    );
  }

  Future<void> _ejecutar(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() accion,
    String exito,
  ) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await accion();
      mensajero.showSnackBar(SnackBar(content: Text(exito)));
      ref.invalidate(invitacionesProvider);
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitaciones = ref.watch(invitacionesProvider);
    final yo = ref.watch(sesionProvider).value?.email.toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      body: invitaciones.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudo cargar el equipo: $e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(invitacionesProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (lista) => RefreshIndicator(
          onRefresh: () => ref.refresh(invitacionesProvider.future),
          child: ListView(
            children: [
              for (final inv in lista)
                ListTile(
                  leading: Icon(
                    inv.rol == 'admin'
                        ? Icons.admin_panel_settings
                        : Icons.badge,
                  ),
                  title: Text(inv.email),
                  subtitle: Text(
                    '${_roles[inv.rol] ?? inv.rol} · '
                    '${inv.activa ? 'activo' : 'pendiente de entrar'}',
                  ),
                  trailing: inv.email == yo
                      ? const Text('Tú')
                      : IconButton(
                          tooltip: 'Quitar acceso',
                          icon: const Icon(Icons.person_remove),
                          onPressed: () => _quitar(context, ref, inv),
                        ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _invitar(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Invitar'),
      ),
    );
  }
}

class _DialogoInvitar extends StatefulWidget {
  const _DialogoInvitar();

  @override
  State<_DialogoInvitar> createState() => _DialogoInvitarState();
}

class _DialogoInvitarState extends State<_DialogoInvitar> {
  final _email = TextEditingController();
  String _rol = 'tecnico';
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
    Navigator.pop(context, (email, _rol));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invitar al equipo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo de Google',
              errorText: _error,
            ),
            onSubmitted: (_) => _aceptar(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _rol,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: [
              for (final r in EquipoScreen._roles.entries)
                DropdownMenuItem(value: r.key, child: Text(r.value)),
            ],
            onChanged: (v) => setState(() => _rol = v ?? 'tecnico'),
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
}
