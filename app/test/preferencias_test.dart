import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trazacafe/services/preferencias.dart';

void main() {
  test('el tema elegido se guarda y se recupera al volver a abrir', () async {
    SharedPreferences.setMockInitialValues({});
    final antes = ProviderContainer();
    addTearDown(antes.dispose);
    expect(antes.read(temaProvider), ThemeMode.system);
    await antes.read(temaProvider.notifier).elegir(ThemeMode.dark);
    expect(antes.read(temaProvider), ThemeMode.dark);

    final despues = ProviderContainer();
    addTearDown(despues.dispose);
    despues.read(temaProvider);
    await Future<void>.delayed(Duration.zero);
    expect(despues.read(temaProvider), ThemeMode.dark);
  });

  test('un valor guardado que no se entiende deja el automático', () async {
    SharedPreferences.setMockInitialValues({'tema': 'morado'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(temaProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(temaProvider), ThemeMode.system);
  });

  test('el idioma del verificador empieza según el navegador y se puede cambiar', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(overrides: [idiomaInicialProvider.overrideWithValue('en')]);
    addTearDown(c.dispose);
    expect(c.read(idiomaProvider), 'en');
    await c.read(idiomaProvider.notifier).elegir('es');
    expect(c.read(idiomaProvider), 'es');
    expect((await SharedPreferences.getInstance()).getString('idioma'), 'es');
  });
}
