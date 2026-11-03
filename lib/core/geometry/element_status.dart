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
}
