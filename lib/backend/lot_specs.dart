/// Características obligatorias y opcionales por categoría (como la tabla
/// "Características del artículo" de eBay). Se guardan en `lots.specs`
/// como mapa clave → texto.
class SpecField {
  const SpecField(this.key, this.label,
      {this.required = false, this.options, this.hint = '', this.numeric = false});

  final String key;
  final String label;
  final bool required;

  /// Si no es nulo, se elige de esta lista.
  final List<String>? options;
  final String hint;
  final bool numeric;
}

const _siNo = ['Sí', 'No'];

const kCategorySpecs = <String, List<SpecField>>{
  'Vehículos': [
    SpecField('marca', 'Marca', required: true, hint: 'Ford'),
    SpecField('modelo', 'Modelo', required: true, hint: 'Lobo XLT'),
    SpecField('anio', 'Año', required: true, numeric: true, hint: '2015'),
    SpecField('km', 'Kilometraje', required: true, numeric: true, hint: '185000'),
    SpecField('transmision', 'Transmisión', required: true, options: ['Automática', 'Estándar']),
    SpecField('combustible', 'Combustible', required: true,
        options: ['Gasolina', 'Diésel', 'Híbrido', 'Eléctrico', 'Gas LP']),
    SpecField('documento', 'Documento de propiedad', required: true,
        options: ['Factura original', 'Refactura', 'Carta factura', 'Título (importado)']),
    SpecField('situacion_legal', 'Situación legal', required: true,
        options: ['Nacional', 'Legalizado/importado', 'Fronterizo']),
    SpecField('tenencias', 'Tenencias/refrendos al corriente', required: true, options: _siNo),
    SpecField('repuve', 'Sin reporte de robo (REPUVE)', required: true, options: _siNo),
    SpecField('placas', 'Placas (estado)', hint: 'Chihuahua'),
    SpecField('fallas', 'Fallas conocidas', hint: 'Ninguna / describe'),
  ],
  'Ganado y caballos': [
    SpecField('especie', 'Especie', required: true,
        options: ['Caballo', 'Bovino', 'Ovino', 'Caprino', 'Porcino', 'Otro']),
    SpecField('raza', 'Raza', required: true, hint: 'Cuarto de milla'),
    SpecField('sexo', 'Sexo', required: true,
        options: ['Macho', 'Hembra', 'Macho castrado', 'Lote mixto']),
    SpecField('edad', 'Edad', required: true, hint: '4 años'),
    SpecField('cabezas', 'Número de cabezas', required: true, numeric: true, hint: '1'),
    SpecField('peso', 'Peso aproximado (kg)', numeric: true, hint: '450'),
    SpecField('arete', 'Arete SINIIGA', required: true, options: ['Sí, todos', 'No']),
    SpecField('guia', 'Guía de tránsito/REEMO disponible', required: true, options: _siNo),
    SpecField('fierro', 'Fierro registrado a nombre del vendedor', required: true, options: _siNo),
    SpecField('vacunas', 'Vacunas y desparasitación', hint: 'Al corriente, mayo 2026'),
    SpecField('registro', 'Registro genealógico', options: ['Sí', 'No', 'En trámite']),
    SpecField('ubicacion', 'Ubicación del animal', required: true, hint: 'Camargo, Chih.'),
  ],
  'Maquinaria y herramientas': [
    SpecField('marca', 'Marca', required: true, hint: 'John Deere'),
    SpecField('modelo', 'Modelo', required: true, hint: '5075E'),
    SpecField('anio', 'Año', numeric: true, hint: '2018'),
    SpecField('horas', 'Horas de uso', numeric: true, hint: '3200'),
    SpecField('funciona', 'Funciona', required: true,
        options: ['Sí, al 100%', 'Sí, con detalles', 'No']),
    SpecField('documento', 'Comprobante de propiedad', required: true,
        options: ['Factura', 'Carta factura', 'Sin factura']),
    SpecField('incluye', 'Qué incluye', hint: 'Implementos, accesorios'),
    SpecField('ubicacion', 'Ubicación', required: true, hint: 'Delicias, Chih.'),
  ],
  'Electrónica': [
    SpecField('marca', 'Marca', required: true, hint: 'Apple'),
    SpecField('modelo', 'Modelo', required: true, hint: 'iPhone 14 Pro'),
    SpecField('capacidad', 'Almacenamiento / capacidad', hint: '256 GB'),
    SpecField('funciona', 'Funciona', required: true,
        options: ['Sí, al 100%', 'Sí, con detalles', 'No (para piezas)']),
    SpecField('liberado', 'Liberado / sin bloqueo de cuenta', required: true,
        options: ['Sí', 'No', 'No aplica']),
    SpecField('bateria', 'Salud de batería', hint: '89%'),
    SpecField('incluye', 'Qué incluye', hint: 'Caja, cargador'),
    SpecField('garantia', 'Garantía', options: ['Sin garantía', 'Del vendedor', 'De fábrica vigente']),
  ],
  'Hogar y muebles': [
    SpecField('material', 'Material', required: true, hint: 'Madera de pino'),
    SpecField('medidas', 'Medidas (largo × ancho × alto)', required: true, hint: '200 × 90 × 85 cm'),
    SpecField('piezas', 'Número de piezas', numeric: true, hint: '3'),
    SpecField('marca', 'Marca', hint: 'Opcional'),
    SpecField('entrega', 'Entrega', required: true,
        options: ['Recoger en domicilio', 'Envío por cuenta del comprador', 'Entrega local incluida']),
  ],
  'Joyería y relojes': [
    SpecField('marca', 'Marca', required: true, hint: 'Seiko / Sin marca'),
    SpecField('material', 'Material', required: true, hint: 'Oro 14k, acero'),
    SpecField('peso', 'Peso (g)', numeric: true, hint: '12'),
    SpecField('autenticidad', 'Comprobante de autenticidad', required: true,
        options: ['Factura/certificado', 'Sin comprobante']),
    SpecField('funciona', 'Funciona (relojes)', options: ['Sí', 'No', 'No aplica']),
  ],
  'Arte y colección': [
    SpecField('autor', 'Autor / fabricante', required: true, hint: 'Desconocido'),
    SpecField('epoca', 'Año o época', hint: '1980'),
    SpecField('medidas', 'Medidas', hint: '60 × 40 cm'),
    SpecField('autenticidad', 'Certificado de autenticidad', required: true, options: _siNo),
  ],
  'Deportes': [
    SpecField('marca', 'Marca', required: true, hint: 'Trek'),
    SpecField('modelo', 'Modelo', hint: 'Marlin 5'),
    SpecField('talla', 'Talla / medida', required: true, hint: 'Rodada 29, talla M'),
    SpecField('incluye', 'Qué incluye', hint: 'Accesorios'),
  ],
  'Ropa y accesorios': [
    SpecField('marca', 'Marca', required: true, hint: 'Original / Sin marca'),
    SpecField('talla', 'Talla', required: true, hint: '27 MX / M'),
    SpecField('genero', 'Para', required: true, options: ['Hombre', 'Mujer', 'Unisex', 'Niño/a']),
    SpecField('material', 'Material', hint: 'Piel'),
  ],
  'Otros': [
    SpecField('marca', 'Marca', hint: 'Opcional'),
    SpecField('medidas', 'Medidas o tamaño', hint: 'Opcional'),
    SpecField('incluye', 'Qué incluye', hint: 'Opcional'),
  ],
};

List<SpecField> specsFor(String category) => kCategorySpecs[category] ?? const [];

/// Regresa la etiqueta de la primera característica obligatoria vacía, o
/// null si todo está completo.
String? missingRequiredSpec(String category, Map<String, String> values) {
  for (final f in specsFor(category)) {
    if (f.required && (values[f.key] ?? '').trim().isEmpty) return f.label;
  }
  return null;
}

/// Pares (etiqueta, valor) para mostrar, en el orden de la categoría.
List<(String, String)> specRows(String category, Map<String, String> values) {
  final rows = <(String, String)>[];
  final known = <String>{};
  for (final f in specsFor(category)) {
    known.add(f.key);
    final v = (values[f.key] ?? '').trim();
    if (v.isNotEmpty) rows.add((f.label, v));
  }
  values.forEach((k, v) {
    if (!known.contains(k) && v.trim().isNotEmpty) rows.add((k, v.trim()));
  });
  return rows;
}
