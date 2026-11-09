/// Estados ontológicos de un elemento constructivo en el modelo de dominio.
/// No son simples colores ni capas visuales.
enum ElementStatus {
  existing,
  preserved,
  toDemolish,
  toModify,
  isNew,
  future,
  reference;

  bool get isDemolishable => this == ElementStatus.toDemolish;
  bool get isPreserved => this == ElementStatus.preserved || this == ElementStatus.existing;
  bool get isConstructed => this == ElementStatus.isNew;

  /// Localized human-readable label for tables and UI badges.
  String displayLabel([String lang = 'es']) {
    final isEs = lang == 'es';
    switch (this) {
      case ElementStatus.isNew:
        return isEs ? 'Nuevo' : 'New';
      case ElementStatus.preserved:
        return isEs ? 'Conservar' : 'Preserved';
      case ElementStatus.existing:
        return isEs ? 'Existente' : 'Existing';
      case ElementStatus.toDemolish:
        return isEs ? 'A Demoler' : 'Demolish';
      case ElementStatus.toModify:
        return isEs ? 'Modificar' : 'Modify';
      case ElementStatus.future:
        return isEs ? 'Futuro' : 'Future';
      case ElementStatus.reference:
        return isEs ? 'Referencia' : 'Reference';
    }
  }

  /// Uppercase technical label for architectural PDF schedules.
  String get pdfBadgeLabelEs {
    switch (this) {
      case ElementStatus.toDemolish:
        return 'A DEMOLER';
      case ElementStatus.preserved:
        return 'EXIST. CONSERVADO';
      case ElementStatus.existing:
        return 'EXISTENTE';
      case ElementStatus.toModify:
        return 'A MODIFICAR';
      case ElementStatus.future:
        return 'FUTURO / ETAPA 2';
      case ElementStatus.reference:
        return 'REFERENCIA';
      case ElementStatus.isNew:
        return 'NUEVO PROPUESTO';
    }
  }
}
