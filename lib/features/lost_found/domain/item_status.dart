enum ItemStatus {
  lost('Perdido'),
  found('Encontrado');

  const ItemStatus(this.label);

  final String label;

  static ItemStatus? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'lost') {
      return ItemStatus.lost;
    }
    if (normalized == 'found') {
      return ItemStatus.found;
    }
    return null;
  }
}
