/// Opciones de implantación del garaje respecto al retiro frontal
enum GaragePlacement {
  none,
  frontSetbackSemiCovered, // Semicubierto / descubierto en el retiro frontal (permitido normativamente)
  frontEnclosed,            // Cerrado con muros detrás de la línea de edificación
}

/// Distribución de dormitorios en Planta Baja
enum GroundFloorBedroomOption {
  none,
  masterSuite, // Suite Principal en Planta Baja
  guestRoom,   // Habitación de visitas / Estudio
}

/// Programa de necesidades arquitectónicas para vivienda de 2 pisos.
class MultiStoryBrief {
  final GaragePlacement garagePlacement;
  final int garageCars; // 1 o 2 autos
  final GroundFloorBedroomOption groundFloorBedroom;
  final bool groundFloorSocialBath;
  final int upperFloorBedrooms; // 2 o 3 dormitorios
  final bool upperFloorPrivateBath;
  final bool upperFloorLivingOrStudy; // Estar íntimo / Estudio arriba

  const MultiStoryBrief({
    this.garagePlacement = GaragePlacement.frontSetbackSemiCovered,
    this.garageCars = 1,
    this.groundFloorBedroom = GroundFloorBedroomOption.masterSuite,
    this.groundFloorSocialBath = true,
    this.upperFloorBedrooms = 2,
    this.upperFloorPrivateBath = true,
    this.upperFloorLivingOrStudy = true,
  });

  MultiStoryBrief copyWith({
    GaragePlacement? garagePlacement,
    int? garageCars,
    GroundFloorBedroomOption? groundFloorBedroom,
    bool? groundFloorSocialBath,
    int? upperFloorBedrooms,
    bool? upperFloorPrivateBath,
    bool? upperFloorLivingOrStudy,
  }) {
    return MultiStoryBrief(
      garagePlacement: garagePlacement ?? this.garagePlacement,
      garageCars: garageCars ?? this.garageCars,
      groundFloorBedroom: groundFloorBedroom ?? this.groundFloorBedroom,
      groundFloorSocialBath:
          groundFloorSocialBath ?? this.groundFloorSocialBath,
      upperFloorBedrooms: upperFloorBedrooms ?? this.upperFloorBedrooms,
      upperFloorPrivateBath:
          upperFloorPrivateBath ?? this.upperFloorPrivateBath,
      upperFloorLivingOrStudy:
          upperFloorLivingOrStudy ?? this.upperFloorLivingOrStudy,
    );
  }
}
