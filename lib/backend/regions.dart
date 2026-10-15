import 'package:shared_preferences/shared_preferences.dart';

/// Municipios de la región (deben coincidir con MUNICIPALITIES de
/// functions/delivery.js y con firestore.rules).
const kMunicipalities = <String, String>{
  'camargo': 'Camargo',
  'jimenez': 'Jiménez',
  'saucillo': 'Saucillo',
  'delicias': 'Delicias',
  'parral': 'Hidalgo del Parral',
  'meoqui': 'Meoqui',
  'la_cruz': 'La Cruz',
  'san_francisco_de_conchos': 'San Francisco de Conchos',
  'chihuahua': 'Chihuahua',
  'cuauhtemoc': 'Cuauhtémoc',
  'otro': 'Otro',
};

String municipalityName(String key) => kMunicipalities[key] ?? '';

/// Municipio preferido del usuario para filtrar (se recuerda en el equipo).
/// '' = toda la región.
class RegionPreference {
  static const _key = 'region_municipality';

  static Future<String> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key) ?? '';
      return kMunicipalities.containsKey(v) ? v : '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> save(String municipality) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, municipality);
    } catch (_) {}
  }
}
