enum BuildingType {
  academic,
  gym,
  restaurant,
  library,
  administration,
  parking,
  building,
  museum,
  other,
  dorm,
}

extension BuildingTypeExtension on BuildingType {
  String get displayName {
    return name[0].toUpperCase() + name.substring(1);
  }
}
