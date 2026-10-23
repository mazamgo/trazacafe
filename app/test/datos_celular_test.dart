import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/celular_compartido_screen.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/datos_celular.dart';
import 'package:trazacafe/services/sync_service.dart';

import 'fakes.dart';

const orgA = 'org-a';
const orgB = 'org-b';

class SubidorNulo implements SubidorArchivos {
  @override
  Future<void> subir(String rutaStorage, File archivo) async {}
}

/// Celular compartido entre organizaciones: los datos de una no se ven ni se
/// envían desde la sesión de otra.
void main() {
  late AppDatabase db;
  late DatosCelular datos;
  late Directory temporal;

  /// Un productor de la organización A con su foto en el celular.
  Future<File> datosDeA({required bool enviados}) async {
    final foto = File('${temporal.path}/consentimiento.jpg')
      ..writeAsStringSync('jpg');
    await db
        .into(db.productores)
        .insert(
          ProductoresCompanion.insert(
            id: 'p1',
            nombre: 'María López',
            sincronizado: Value(enviados),
          ),
        );
    await db
        .into(db.fotos)
        .insert(
          FotosCompanion.insert(
            id: 'foto1',
            entidadTipo: 'productor',
            entidadId: 'p1',
            tipo: 'consentimiento',
            ruta: foto.path,
            sha256: 'abc',
            sincronizado: Value(enviados),
            subida: Value(enviados),
          ),
        );
    await db.guardarAjuste(ClaveAjuste.organizacionDatos, orgA);
    return foto;
  }

  Future<int> productores() async =>
      (await db.select(db.productores).get()).length;

  group('servicio', () {
    setUp(() {
      temporal = Directory.systemTemp.createTempSync('trazacafe_celular');
      db = AppDatabase(NativeDatabase.memory());
      datos = DatosCelular(db);
    });
    tearDown(() async {
      await db.close();
      temporal.deleteSync(recursive: true);
    });

    group('prepararPara', () {
      test('un celular sin dueña (nuevo o de antes de esta versión) queda de quien entra', () async {
        expect(await datos.prepararPara(orgA), 0);
        expect(await db.leerAjuste(ClaveAjuste.organizacionDatos), orgA);
      });

      test(
        'la misma organización conserva sus datos, aunque falte enviarlos',
        () async {
          await datosDeA(enviados: false);
          expect(await datos.prepararPara(orgA), 0);
          expect(await productores(), 1);
        },
      );

      test(
        'otra organización: si todo se envió, se borra solo con las fotos',
        () async {
          final foto = await datosDeA(enviados: true);
          expect(await datos.prepararPara(orgB), 0);
          expect(await productores(), 0);
          expect(foto.existsSync(), isFalse);
          expect(await db.leerAjuste(ClaveAjuste.organizacionDatos), orgB);
        },
      );

      test('otra organización con datos sin enviar: no borra nada y dice cuántos son', () async {
        final foto = await datosDeA(enviados: false);
        expect(
          await datos.prepararPara(orgB),
          2,
          reason: 'el productor y su foto',
        );
        expect(await productores(), 1);
        expect(foto.existsSync(), isTrue);
        expect(await db.leerAjuste(ClaveAjuste.organizacionDatos), orgA);
      });
    });

    test(
      'borrarPara descarta lo sin enviar y deja el celular a la nueva',
      () async {
        final foto = await datosDeA(enviados: false);
        await datos.borrarPara(orgB);
        expect(await productores(), 0);
        expect(foto.existsSync(), isFalse);
        expect(await datos.prepararPara(orgB), 0);
      },
    );

    test('la sincronización se niega con datos de otra organización', () async {
      await datosDeA(enviados: false);
      final auth = AuthFalso(
        inicial: const Sesion(
          uid: 'u2',
          email: 'b@coop.org',
          organizacionId: orgB,
          rol: 'tecnico',
        ),
      );
      final api = ApiFalsa({});
      final sync = SyncService(
        db,
        api.cliente(auth),
        SubidorNulo(),
        () => orgB,
      );
      await expectLater(
        sync.sincronizar(),
        throwsA(isA<DatosDeOtraOrganizacion>()),
      );
      expect(api.peticiones, isEmpty, reason: 'nada viajó a la organización B');
    });
  });

  group('pantalla', () {
    Future<void> abrir(WidgetTester tester, AuthFalso auth) async {
      late AppDatabase base;
      await tester.runAsync(() async {
        base = AppDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        await base
            .into(base.productores)
            .insert(
              ProductoresCompanion.insert(id: 'p1', nombre: 'María López'),
            );
        await base.guardarAjuste(ClaveAjuste.organizacionDatos, orgA);
      });
      db = base;
      addTearDown(() => tester.runAsync(base.close));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(base),
            authServiceProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(
            home: CelularListo(
              organizacionId: orgB,
              child: Text('App de la organización B'),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    testWidgets(
      'pide cerrar sesión para que la otra organización envíe lo suyo',
      (tester) async {
        final auth = AuthFalso(
          inicial: const Sesion(
            uid: 'u2',
            email: 'b@coop.org',
            organizacionId: orgB,
            rol: 'tecnico',
          ),
        );
        await abrir(tester, auth);
        expect(find.text('App de la organización B'), findsNothing);
        expect(find.textContaining('1 registros sin enviar'), findsOneWidget);
        await tester.tap(find.text('Cerrar sesión'));
        await tester.pump();
        expect(auth.cierres, 1);
      },
    );

    testWidgets('o borrarlos, con confirmación, y entrar', (tester) async {
      await abrir(tester, AuthFalso());
      await tester.tap(find.text('Borrar esos datos y continuar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no se pueden recuperar'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.text('App de la organización B'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.productores).get()),
        isEmpty,
      );
    });
  });
}
