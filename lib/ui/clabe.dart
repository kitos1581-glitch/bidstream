/// Valida una CLABE interbancaria (18 dígitos con dígito verificador).
/// Pesos 3,7,1 sobre los primeros 17 dígitos; el 18 es el verificador.
bool isValidClabe(String input) {
  final clabe = input.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{18}$').hasMatch(clabe)) return false;
  const weights = [3, 7, 1];
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    sum += (int.parse(clabe[i]) * weights[i % 3]) % 10;
  }
  final check = (10 - (sum % 10)) % 10;
  return check == int.parse(clabe[17]);
}
