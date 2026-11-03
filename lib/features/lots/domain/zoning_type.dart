/// Tipos de zonificación normativa de un terreno o lote.
enum ZoningType {
  nonBuildable,
  buildableUnoccupied,
  futureReserved,
  occupied,
  exterior,
  other;

  bool get allowsConstruction =>
      this == ZoningType.buildableUnoccupied || this == ZoningType.occupied;
}
