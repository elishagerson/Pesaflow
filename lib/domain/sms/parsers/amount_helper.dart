int parseAmount(String val) {
  if (val.isEmpty) return 0;
  final clean = val
      .replaceAll(RegExp(r'[^\d.,-]'), '')
      .replaceAll(',', '')
      .trim();
  if (clean.isEmpty || clean == '.') return 0;
  final doubleVal = double.tryParse(clean);
  if (doubleVal == null || doubleVal < 0) return 0;
  return (doubleVal * 100).round();
}
