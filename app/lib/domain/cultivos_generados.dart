// GENERADO por schemas/scripts/cultivos-dart.ts desde schemas/cultivos.json.
// No editar a mano: cambia el JSON y corre `npm run cultivos-dart` en schemas/.
part of 'cultivos.dart';

const cultivosGenerados = <Cultivo>[
  Cultivo(
    id: 'cafe',
    nombre: 'Café',
    codigoHS: '0901',
    color: 0xFF6F4E37,
    maxKgEntrega: 20000,
    maxKgExportableHa: 2500,
    estados: [
      EstadoEntrega(
        id: 'uva',
        nombre: 'Uva (café maduro)',
        corto: 'Uva',
        factorExportable: 0.16,
      ),
      EstadoEntrega(
        id: 'pergamino',
        nombre: 'Pergamino',
        corto: 'Pergamino',
        factorExportable: 0.80,
      ),
      EstadoEntrega(
        id: 'oro',
        nombre: 'Oro (café verde)',
        corto: 'Oro',
        factorExportable: 1.00,
      ),
    ],
  ),
  Cultivo(
    id: 'cacao',
    nombre: 'Cacao',
    codigoHS: '1801',
    color: 0xFF8D5524,
    maxKgEntrega: 20000,
    maxKgExportableHa: 2000,
    estados: [
      EstadoEntrega(
        id: 'baba',
        nombre: 'En baba (fresco)',
        corto: 'Baba',
        factorExportable: 0.38,
      ),
      EstadoEntrega(
        id: 'fermentado',
        nombre: 'Fermentado',
        corto: 'Fermentado',
        factorExportable: 0.45,
      ),
      EstadoEntrega(
        id: 'seco',
        nombre: 'Seco',
        corto: 'Seco',
        factorExportable: 1.00,
      ),
    ],
  ),
];
