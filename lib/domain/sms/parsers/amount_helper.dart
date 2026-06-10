int parseAmount(String val) {
  final clean = val.replaceAll(',', '').trim();
  final doubleVal = double.tryParse(clean) ?? 0.0;
  return (doubleVal * 100).round();
}
