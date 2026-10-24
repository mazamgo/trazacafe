import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/preferencias.dart';
import 'contenedores_screen.dart';
import 'cultivos_screen.dart';
import 'equipo_screen.dart';
import 'lotes_screen.dart';
import 'mapas_sin_senal_screen.dart';
import 'finca_screen.dart' show fecha;
import 'nuevo_productor_screen.dart';
import 'privacidad_screen.dart';
import 'solicitudes_eliminacion_screen.dart';
import 'productor_screen.dart';
import 'temporadas_screen.dart';

/// Pantalla principal del técnico: productores de su cooperativa.
class ProductoresScreen extends ConsumerWidget {
  const ProductoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoSyncProvider);
    final productores = ref.watch(productoresProvider);
    final sesion = ref.watch(sesionProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productores'),
        actions: [
          const BotonSincronizar(),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              if (sesion != null)
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    '${sesion.email}\n${sesion.esAdmin ? 'Administrador' : 'Técnico'}',
                  ),
                ),
              PopupMenuItem(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TemporadasScreen()),
                ),
                child: const Text('Temporadas'),
              ),
              if (sesion?.esAdmin ?? false)
                PopupMenuItem(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EquipoScreen()),
                  ),
                  child: const Text('Equipo'),
                ),
              if (sesion?.esAdmin ?? false)
                PopupMenuItem(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CultivosScreen()),
                  ),
                  child: const Text('Cultivos'),
                ),
              if (sesion?.esAdmin ?? false)
                PopupMenuItem(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LotesScreen()),
                  ),
                  child: const Text('Lotes'),
                ),
              if (sesion?.esAdmin ?? false)
                PopupMenuItem(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ContenedoresScreen(),
                    ),
                  ),
                  child: const Text('Contenedores'),
                ),
              PopupMenuItem(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MapasSinSenalScreen()),
                ),
                child: const Text('Mapas sin señal'),
              ),
              PopupMenuItem(
                onTap: () => elegirTema(context),
                child: const Text('Tema'),
              ),
              PopupMenuItem(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacidadScreen()),
                ),
                child: const Text('Privacidad y datos'),
              ),
              PopupMenuItem(
                onTap: () => ref.read(authServiceProvider).cerrarSesion(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (ref.watch(eliminacionProgramadaProvider).value case final dia?)
            MaterialBanner(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              leading: const Icon(Icons.event_busy),
              content: Text(
                'La organización se eliminará el ${fecha(dia)}. '
                '${sesion?.esAdmin ?? false ? 'Puedes cancelarlo en Privacidad y datos.' : 'Habla con el administrador si es un error.'}',
              ),
              actions: [
                if (sesion?.esAdmin ?? false)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacidadScreen(),
                      ),
                    ),
                    child: const Text('Ver'),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          if ((sesion?.esAdmin ?? false) &&
              (ref.watch(solicitudesPendientesProvider).value ?? 0) > 0)
            MaterialBanner(
              leading: const Icon(Icons.mark_email_unread_outlined),
              content: Text(
                '${ref.watch(solicitudesPendientesProvider).value} '
                '${ref.watch(solicitudesPendientesProvider).value == 1 ? 'productor pide' : 'productores piden'} '
                'que se borren sus datos.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SolicitudesEliminacionScreen(),
                    ),
                  ),
                  child: const Text('Responder'),
                ),
              ],
            ),
          if (ref.watch(temporadasProvider).hasValue &&
              ref.watch(temporadaActualProvider) == null)
            MaterialBanner(
              leading: const Icon(Icons.event_busy),
              content: Text(
                sesion?.esAdmin ?? false
                    ? 'No hay temporada de cosecha para hoy. Créala para agrupar entregas y visitas.'
                    : 'No hay temporada de cosecha para hoy. Pide al administrador que la cree.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TemporadasScreen()),
                  ),
                  child: const Text('Temporadas'),
                ),
              ],
            ),
          Expanded(
            child: productores.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (lista) => lista.isEmpty
                  ? const Center(
                      child: Text(
                        'Aún no hay productores. Toca + para agregar.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: lista.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final x = lista[i];
                        return ListTile(
                          leading: Icon(
                            x.productor.anonimizado
                                ? Icons.person_off_outlined
                                : Icons.person,
                          ),
                          title: Text(x.productor.nombre),
                          subtitle: Text(
                            [
                              if (x.productor.anonimizado)
                                'Datos personales eliminados',
                              if (x.productor.comunidad != null)
                                x.productor.comunidad!,
                              '${x.fincas} ${x.fincas == 1 ? 'finca' : 'fincas'}',
                            ].join(' · '),
                          ),
                          trailing: x.productor.sincronizado
                              ? null
                              : const Icon(
                                  Icons.cloud_upload,
                                  color: Colors.orange,
                                ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductorScreen(productor: x.productor),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo productor',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NuevoProductorScreen())),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

/// Botón de la barra con la cantidad de registros sin enviar.
class BotonSincronizar extends ConsumerStatefulWidget {
  const BotonSincronizar({super.key});

  @override
  ConsumerState<BotonSincronizar> createState() => _BotonSincronizarState();
}

class _BotonSincronizarState extends ConsumerState<BotonSincronizar> {
  bool _enviando = false;

  Future<void> _sincronizar() async {
    setState(() => _enviando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(syncServiceProvider).sincronizar();
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            [
              if (r.enviados > 0) 'Enviados ${r.enviados} registros.',
              if (r.fotosSubidas > 0) 'Subidas ${r.fotosSubidas} fotos.',
              if (r.errorFotos != null)
                'Algunas fotos no se subieron: ${r.errorFotos}',
              if (r.enviados == 0 &&
                  r.fotosSubidas == 0 &&
                  r.errorFotos == null)
                'Todo está al día.',
            ].join(' '),
          ),
        ),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar: $e')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = ref.watch(pendientesProvider).value ?? 0;
    return IconButton(
      tooltip: 'Sincronizar',
      onPressed: _enviando ? null : _sincronizar,
      icon: _enviando
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Badge(
              isLabelVisible: pendientes > 0,
              label: Text('$pendientes'),
              child: const Icon(Icons.sync),
            ),
    );
  }
}
