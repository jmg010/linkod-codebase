/// Purok labels for Barangay Cagbaoto: Purok Uno, Dos, Tres, Quatro, Singko.
/// Used in profile, menu, and when creating posts/products/errands.

const List<String> purokLabels = [
  'Purok Uno',
  'Purok Dos',
  'Purok Tres',
  'Purok Quatro',
  'Purok Singko',
];

/// 1-based purok number (1..5) to display label.
String purokDisplayName(int purokNumber) {
  final index = (purokNumber.clamp(1, 5)) - 1;
  return purokLabels[index];
}

/// Display label to 1-based purok number (1..5). Returns 1 if not found.
int purokFromDisplayName(String label) {
  final i = purokLabels.indexOf(label);
  return i >= 0 ? i + 1 : 1;
}
