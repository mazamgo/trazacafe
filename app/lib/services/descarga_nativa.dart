/// Fuera del navegador no hay descarga: se usa `CompartidorSistema`.
void descargarArchivo(String nombre, List<int> bytes, String tipo) =>
    throw UnsupportedError('La descarga directa solo existe en la web.');
