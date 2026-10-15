import 'package:cloud_firestore/cloud_firestore.dart';

import 'schema/bids_record.dart';
import 'schema/lots_record.dart';

/// Lotes de DEMOSTRACIÓN para la vista previa (no existen en Firestore).
/// Se activan compilando con --dart-define=DEMO_LOTS=true.
/// Antes del lanzamiento, compilar SIN esa bandera y desaparecen.
const kShowDemoLots = bool.fromEnvironment('DEMO_LOTS', defaultValue: false);

bool isDemoLotId(String id) => id.startsWith('demo-');

class _Demo {
  const _Demo(this.id, this.title, this.category, this.condition, this.emoji,
      this.c1, this.c2, this.start, this.bid, this.inc, this.bids,
      this.endsIn, {this.live = false, this.startsIn = Duration.zero, this.desc = ''});
  final String id, title, category, condition, emoji, c1, c2, desc;
  final double start, bid, inc;
  final int bids;
  final Duration endsIn, startsIn;
  final bool live;
}

final _items = <_Demo>[
  const _Demo('demo-1', 'Caballo Cuarto de Milla, 4 años, con registro', 'Ganado y caballos',
      'used_good', '🐎', '0xFF8D6E63', '0xFFFFE0B2', 60000, 87500, 2500, 14,
      Duration(minutes: 42), live: true,
      desc: 'Qué es:\nCaballo Cuarto de Milla alazán de 4 años.\nEstado:\nSano, herrado, manso.\nIncluye:\nRegistro AQHA y certificado de salud.\nDetalles a considerar:\nSin detalles visibles en las fotos.'),
  const _Demo('demo-2', 'Ford Lobo 2015 XLT 4x4, 120 mil km', 'Vehículos', 'used_good', '🛻',
      '0xFF1565C0', '0xFFBBDEFB', 180000, 214000, 2000, 23, Duration(hours: 5, minutes: 10)),
  const _Demo('demo-3', 'Tractor John Deere 5075E, 2018', 'Maquinaria y herramientas',
      'used_fair', '🚜', '0xFF2E7D32', '0xFFFFF59D', 350000, 365000, 5000, 6,
      Duration(days: 2, hours: 3)),
  const _Demo('demo-4', 'iPhone 15 Pro 256 GB, titanio natural', 'Electrónica', 'like_new',
      '📱', '0xFF455A64', '0xFFCFD8DC', 9000, 13250, 250, 31, Duration(minutes: 18)),
  const _Demo('demo-5', 'Lote de 10 novillos Charolais, 350 kg prom.', 'Ganado y caballos',
      'used_good', '🐂', '0xFFA1887F', '0xFFF1F8E9', 150000, 150000, 5000, 0,
      Duration(hours: 3), live: true, startsIn: Duration(hours: 1)),
  const _Demo('demo-6', 'Reloj Seiko Presage automático', 'Joyería y relojes', 'new', '⌚',
      '0xFF37474F', '0xFFFFECB3', 6500, 7400, 200, 9, Duration(days: 1, hours: 6)),
  const _Demo('demo-7', 'Silla de montar de piel, hecha a mano', 'Ganado y caballos',
      'used_good', '🏇', '0xFF6D4C41', '0xFFFFCC80', 8000, 9600, 300, 7,
      Duration(hours: 9)),
  const _Demo('demo-8', 'Laptop MacBook Air M2, 8 GB / 256 GB', 'Electrónica', 'used_good',
      '💻', '0xFF5E35B1', '0xFFD1C4E9', 12000, 15800, 250, 18, Duration(hours: 1, minutes: 5)),
  const _Demo('demo-9', 'Guitarra acústica Yamaha FG800', 'Arte y colección', 'like_new', '🎸',
      '0xFFE65100', '0xFFFFE0B2', 2500, 3100, 100, 5, Duration(days: 3)),
  const _Demo('demo-10', 'Bicicleta de montaña rodada 29, Trek', 'Deportes', 'used_fair', '🚲',
      '0xFF00897B', '0xFFB2DFDB', 4000, 5200, 200, 11, Duration(hours: 20)),
  const _Demo('demo-11', 'Sala de 3 piezas, tela gris', 'Hogar y muebles', 'used_good', '🛋️',
      '0xFF757575', '0xFFF5F5F5', 5000, 5000, 250, 0, Duration(days: 4)),
  const _Demo('demo-12', 'Generador Honda 5,500 W', 'Maquinaria y herramientas', 'new', '⚡',
      '0xFFC62828', '0xFFFFF9C4', 14000, 16750, 500, 8, Duration(hours: 30)),
];

/// Características de ejemplo (como las publicaría un vendedor cuidadoso).
const _demoSpecs = <String, Map<String, String>>{
  'demo-1': {
    'especie': 'Caballo', 'raza': 'Cuarto de milla', 'sexo': 'Macho castrado',
    'edad': '4 años', 'cabezas': '1', 'peso': '480', 'arete': 'Sí, todos',
    'guia': 'Sí', 'fierro': 'Sí', 'vacunas': 'Al corriente (mayo 2026)',
    'registro': 'Sí', 'ubicacion': 'Camargo, Chih.',
  },
  'demo-2': {
    'marca': 'Ford', 'modelo': 'Lobo XLT 4x4', 'anio': '2015', 'km': '120000',
    'transmision': 'Automática', 'combustible': 'Gasolina',
    'documento': 'Factura original', 'situacion_legal': 'Nacional',
    'tenencias': 'Sí', 'repuve': 'Sí', 'placas': 'Chihuahua',
    'fallas': 'Ninguna conocida',
  },
  'demo-3': {
    'marca': 'John Deere', 'modelo': '5075E', 'anio': '2018', 'horas': '3200',
    'funciona': 'Sí, con detalles', 'documento': 'Factura',
    'incluye': 'Rastra de 20 discos', 'ubicacion': 'Delicias, Chih.',
  },
  'demo-4': {
    'marca': 'Apple', 'modelo': 'iPhone 15 Pro', 'capacidad': '256 GB',
    'funciona': 'Sí, al 100%', 'liberado': 'Sí', 'bateria': '94%',
    'incluye': 'Caja y cable', 'garantia': 'Sin garantía',
  },
  'demo-5': {
    'especie': 'Bovino', 'raza': 'Charolais', 'sexo': 'Macho', 'edad': '14 meses',
    'cabezas': '10', 'peso': '350', 'arete': 'Sí, todos', 'guia': 'Sí',
    'fierro': 'Sí', 'ubicacion': 'Jiménez, Chih.',
  },
};

DocumentReference _ref(String id) =>
    FirebaseFirestore.instance.collection('lots').doc(id);

LotsRecord _build(_Demo d, DateTime now) {
  final start = now.add(d.startsIn);
  return LotsRecord.fromMap(_ref(d.id), {
    'title': d.title,
    'description': d.desc.isNotEmpty
        ? d.desc
        : 'Qué es:\n${d.title}.\nEstado:\nLote de demostración para mostrar cómo se ve la app.\nDetalles a considerar:\nEste lote no es real.',
    'category': d.category,
    'condition': d.condition,
    'image_urls': ['emoji:${d.emoji}:${d.c1}:${d.c2}'],
    'starting_price': d.start,
    'current_bid': d.bid,
    'minimum_increment': d.inc,
    'bid_count': d.bids,
    'start_time': Timestamp.fromDate(d.startsIn > Duration.zero ? start : now.subtract(const Duration(days: 1))),
    'end_time': Timestamp.fromDate(start.add(d.endsIn)),
    'status': 'active',
    'format': d.live ? 'live' : 'timed',
    'stream_url': '',
    'seller_uid': 'demo-seller',
    'seller_name': 'Vendedor Demo',
    'highest_bidder_uid': d.bids > 0 ? 'demo-bidder' : null,
    'highest_bidder_name': d.bids > 0 ? 'Juan P.' : null,
    if (_demoSpecs[d.id] != null) 'specs': _demoSpecs[d.id],
  });
}

// Las fechas se fijan una vez por sesión para que las cuentas regresivas avancen.
final DateTime _anchor = DateTime.now();

List<LotsRecord> demoLots() =>
    kShowDemoLots ? [for (final d in _items) _build(d, _anchor)] : const [];

LotsRecord? demoLot(String id) {
  for (final d in _items) {
    if (d.id == id) return _build(d, _anchor);
  }
  return null;
}

List<BidsRecord> demoBids(String lotId) {
  final lot = demoLot(lotId);
  if (lot == null || lot.bidCount == 0) return const [];
  final names = ['Juan P.', 'María G.', 'Luis R.', 'Ana S.', 'Pedro M.'];
  final out = <BidsRecord>[];
  var amount = lot.currentBid;
  for (var i = 0; i < lot.bidCount.clamp(0, 5); i++) {
    out.add(BidsRecord.fromMap(_ref(lotId).collection('history').doc('d$i'), {
      'bidder_uid': 'demo-$i',
      'bidder_name': names[i % names.length],
      'amount': amount,
      'auto': i % 3 == 1,
      'created_time': Timestamp.fromDate(_anchor.subtract(Duration(minutes: 7 * i + 2))),
    }));
    amount -= lot.minimumIncrement;
    if (amount < lot.startingPrice) break;
  }
  return out;
}
