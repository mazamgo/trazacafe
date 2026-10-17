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
    estados: [
      EstadoEntrega(id: 'uva', nombre: 'Uva (café maduro)', corto: 'Uva'),
      EstadoEntrega(id: 'pergamino', nombre: 'Pergamino', corto: 'Pergamino'),
      EstadoEntrega(id: 'oro', nombre: 'Oro (café verde)', corto: 'Oro'),
    ],
  ),
  Cultivo(
    id: 'cacao',
    nombre: 'Cacao',
    codigoHS: '1801',
    color: 0xFF8D5524,
    maxKgEntrega: 20000,
    estados: [
      EstadoEntrega(id: 'baba', nombre: 'En baba (fresco)', corto: 'Baba'),
      EstadoEntrega(
        id: 'fermentado',
        nombre: 'Fermentado',
        corto: 'Fermentado',
      ),
      EstadoEntrega(id: 'seco', nombre: 'Seco', corto: 'Seco'),
    ],
  ),
];
