enum BuildingType {
  academic,
  gym,
  restaurant,
  library,
  administration,
  parking,
}

extension BuildingTypeExtension on BuildingType {
  String get displayName {
    return name[0].toUpperCase() + name.substring(1);
  }
}
