import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de quien usa la app o el verificador: se guardan en el
/// celular (o en el navegador). Si no se pueden leer o guardar, se usa el
/// valor por defecto y la app sigue igual.
abstract class _Preferencia<T> extends Notifier<T> {
  String get clave;
  T get porDefecto;
  T? desdeTexto(String texto);
  String aTexto(T valor);

  bool _elegido = false;

  @override
  T build() {
    _cargar();
    return porDefecto;
  }

  Future<void> _cargar() async {
    try {
      final texto = (await SharedPreferences.getInstance()).getString(clave);
      final valor = texto == null ? null : desdeTexto(texto);
      // Si la persona ya eligió mientras se leía, gana su elección.
      if (valor != null && !_elegido) state = valor;
    } catch (_) {}
  }

  Future<void> elegir(T valor) async {
    _elegido = true;
    state = valor;
    try {
      await (await SharedPreferences.getInstance()).setString(
        clave,
        aTexto(valor),
      );
    } catch (_) {}
  }
}

/// Tema: automático (el del sistema), claro u oscuro.
final temaProvider = NotifierProvider<Tema, ThemeMode>(Tema.new);

class Tema extends _Preferencia<ThemeMode> {
  @override
  String get clave => 'tema';
  @override
  ThemeMode get porDefecto => ThemeMode.system;
  @override
  ThemeMode? desdeTexto(String texto) =>
      ThemeMode.values.where((m) => m.name == texto).firstOrNull;
  @override
  String aTexto(ThemeMode valor) => valor.name;
}

/// Idioma del verificador si nadie eligió: español para quien tiene el
/// navegador en español; inglés para todos los demás (compradores).
final idiomaInicialProvider = Provider<String>(
  (ref) =>
      PlatformDispatcher.instance.locale.languageCode == 'es' ? 'es' : 'en',
);

/// Idioma del verificador público: `es` o `en`.
final idiomaProvider = NotifierProvider<Idioma, String>(Idioma.new);

class Idioma extends _Preferencia<String> {
  @override
  String get clave => 'idioma';
  @override
  String get porDefecto => ref.watch(idiomaInicialProvider);
  @override
  String? desdeTexto(String texto) =>
      const ['es', 'en'].contains(texto) ? texto : null;
  @override
  String aTexto(String valor) => valor;
}

/// Colores de la app, claros y oscuros, a partir del café.
const _semilla = Color(0xFF6F4E37);
final temaClaro = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _semilla),
);
final temaOscuro = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _semilla,
    brightness: Brightness.dark,
  ),
);

/// Diálogo para elegir el tema (menú ⋮ → Tema).
Future<void> elegirTema(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => Consumer(
    builder: (c, ref, _) => AlertDialog(
      title: const Text('Tema'),
      content: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto),
            label: Text('Automático'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode),
            label: Text('Claro'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode),
            label: Text('Oscuro'),
          ),
        ],
        selected: {ref.watch(temaProvider)},
        onSelectionChanged: (s) =>
            ref.read(temaProvider.notifier).elegir(s.first),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Listo'),
        ),
      ],
    ),
  ),
);
