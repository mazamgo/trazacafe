import '../domain/cultivos.dart';

/// Textos del verificador público en español e inglés (el comprador suele
/// estar en Europa). La app de campo sigue solo en español.
class Textos {
  const Textos._(this.idioma);

  final String idioma;

  static const es = Textos._('es');
  static const en = Textos._('en');
  static Textos de(String idioma) => idioma == 'en' ? en : es;

  bool get _en => idioma == 'en';
  String _t(String es, String en) => _en ? en : es;

  /// Va debajo de "TrazaCafé" en la barra de arriba.
  String get titulo => _t('Verificar origen', 'Verify origin');
  String get escanea => _t(
    'Escanea el código QR del contenedor o del saco para ver de qué fincas '
        'viene y su registro en la blockchain.',
    'Scan the QR code on the container or bag to see which farms it comes '
        'from and its record on the blockchain.',
  );
  String get noEncontrado => _t(
    'Este código no corresponde a ningún contenedor ni lote registrado en la '
        'blockchain.',
    'This code does not match any container or lot registered on the '
        'blockchain.',
  );
  String get errorCarga => _t(
    'No se pudo cargar la información. Revisa tu conexión e inténtalo de nuevo.',
    'The information could not be loaded. Check your connection and try again.',
  );
  String get redPrueba =>
      _t('Red de pruebas (OP Sepolia)', 'Test network (OP Sepolia)');
  String get redPruebaDetalle => _t(
    'Estos registros son de prueba. En producción se firman en OP Mainnet.',
    'These are test records. In production they are signed on OP Mainnet.',
  );

  String contenedor(String? numero) => _t(
    'Contenedor ${numero ?? 'sin número'}',
    'Container ${numero ?? 'without number'}',
  );
  String lote(String codigo) => _t('Lote $codigo', 'Lot $codigo');
  String destino(String d) => _t('Destino: $d', 'Destination: $d');
  String dds(String? ref) =>
      'DDS (TRACES): ${ref ?? _t('pendiente', 'pending')}';
  String embarque(String fecha) => _t('Embarque: $fecha', 'Shipment: $fecha');
  String exportador(String o) => _t('Exportador: $o', 'Exporter: $o');

  String proveedores(List<String> o) =>
      _t('Proveedores: ${o.join(', ')}', 'Suppliers: ${o.join(', ')}');

  String get sinBlockchain => _t(
    'No se pudo consultar la blockchain ahora',
    'The blockchain could not be checked right now',
  );
  String get verificado =>
      _t('Verificado en la blockchain', 'Verified on the blockchain');
  String get noCoincide => _t(
    'Atención: no coincide con la blockchain',
    'Warning: does not match the blockchain',
  );
  String get revisarExplorador => _t(
    'Los registros se pueden revisar directamente en el explorador de EAS.',
    'The records can be checked directly in the EAS explorer.',
  );
  String get noExiste => _t(
    'El código no existe en la blockchain.',
    'The code does not exist on the blockchain.',
  );
  String firmadoPor(String direccion, String fecha) => _t(
    'Firmado por TrazaCafé ($direccion) el $fecha',
    'Signed by TrazaCafé ($direccion) on $fecha',
  );
  String get noFirmoTrazaCafe => _t(
    'No lo firmó la clave de TrazaCafé',
    'Not signed by the TrazaCafé key',
  );
  String get vigente => _t('Vigente (no revocado)', 'Valid (not revoked)');
  String get revocado => _t('Revocado', 'Revoked');
  String get coinciden => _t(
    'Los datos de esta página coinciden con lo firmado',
    'The data on this page matches what was signed',
  );
  String noCoinciden(List<String> que) =>
      _t('No coinciden: ', 'Does not match: ') + que.map(_dato).join(', ');
  String get verExplorador =>
      _t('Ver en el explorador (EAS)', 'View in the explorer (EAS)');
  String get verBlockchain =>
      _t('Ver en la blockchain', 'View on the blockchain');

  /// Nombres de los datos que `comprobar` compara.
  String _dato(String clave) => switch (clave) {
    'tipo' => _t('tipo de registro', 'record type'),
    'cultivo' => _t('cultivo', 'crop'),
    'lotes' => _t('lotes', 'lots'),
    'kg' => 'kg',
    'contenedor' => _t('contenedor', 'container'),
    'destino' => _t('destino', 'destination'),
    'DDS' => 'DDS',
    'temporada' => _t('temporada', 'season'),
    'entregas' => _t('entregas', 'deliveries'),
    'estado' => _t('estado', 'state'),
    'beneficio' => _t('beneficio', 'mill'),
    'proceso' => _t('proceso', 'process'),
    'datos' => _t('datos ilegibles', 'unreadable data'),
    _ => clave,
  };

  String lotes(int n) => n == 1 ? _t('Lote', 'Lot') : _t('Lotes', 'Lots');
  String temporada(String t) => _t('Temporada $t', 'Season $t');
  String fincasDeOrigen(int n) =>
      _t('Fincas de origen ($n)', 'Farms of origin ($n)');
  String finca(int numero, String ha, String kg) => _t(
    'Finca $numero · $ha ha · $kg kg en este envío',
    'Farm $numero · $ha ha · $kg kg in this shipment',
  );
  String lindero(int version) => _t(
    'Lindero georreferenciado (versión $version)',
    'Geolocated boundary (version $version)',
  );
  String deforestacion(String resultado) => switch (resultado) {
    'verde' => _t(
      'Sin deforestación después de 2020',
      'No deforestation after 2020',
    ),
    'amarillo' => _t(
      'Pérdida de bosque menor a 0.1 ha después de 2020',
      'Forest loss under 0.1 ha after 2020',
    ),
    'rojo' => _t('Deforestación después de 2020', 'Deforestation after 2020'),
    _ => _t('Chequeo satelital pendiente', 'Satellite check pending'),
  };
  String visita(String fecha) =>
      _t('Visita de verificación: $fecha', 'Verification visit: $fecha');
  String entrega(String fecha, String kg, String estado) =>
      _t('Entrega $fecha · $kg kg $estado', 'Delivery $fecha · $kg kg $estado');
  String get privacidad => _t(
    'Esta página no muestra datos personales: ni nombres de productores o '
        'fincas, ni documentos de identidad. La ubicación es aproximada (~1 km); '
        'la geolocalización exacta va en la declaración de diligencia debida '
        '(EUDR) para las autoridades de la Unión Europea.',
    'This page shows no personal data: no names of producers or farms, and '
        'no ID documents. The location is approximate (~1 km); the exact '
        'geolocation goes in the due diligence statement (EUDR) for the '
        'European Union authorities.',
  );

  String get idiomaOtro => _t('English', 'Español');
  String get tema => _t('Tema', 'Theme');
  String get temaAutomatico => _t('Automático', 'Automatic');
  String get temaClaro => _t('Claro', 'Light');
  String get temaOscuro => _t('Oscuro', 'Dark');

  /// Nombre del cultivo (en español viene de `cultivos.json`).
  String cultivo(Cultivo c) => !_en
      ? c.nombre
      : switch (c.id) {
          'cafe' => 'Coffee',
          'cacao' => 'Cocoa',
          _ => c.nombre,
        };

  /// Estado de una entrega o un lote, en minúsculas para ir en una frase.
  String estado(Cultivo c, String estado) => !_en
      ? c.nombreEstado(estado).toLowerCase()
      : switch (estado) {
          'uva' => 'coffee cherry',
          'pergamino' => 'parchment coffee',
          'oro' => 'green coffee',
          'baba' => 'wet cocoa beans',
          'fermentado' => 'fermented cocoa',
          'seco' => 'dried cocoa beans',
          _ => c.nombreEstado(estado).toLowerCase(),
        };
}
