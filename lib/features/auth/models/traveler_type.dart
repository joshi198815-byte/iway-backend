enum TravelerType {
  avionIdaVuelta,
  avionTierra,
  soloTierra,
}

extension TravelerTypeExtension on TravelerType {
  String get label {
    switch (this) {
      case TravelerType.avionIdaVuelta:
        return 'Guatemala ↔ USA (Avión)';
      case TravelerType.avionTierra:
        return 'Guatemala → USA (Avión) / USA → Guatemala (Tierra)';
      case TravelerType.soloTierra:
        return 'USA → Guatemala (Tierra)';
    }
  }

  String get apiValue {
    switch (this) {
      case TravelerType.avionIdaVuelta:
        return 'avion_ida_vuelta';
      case TravelerType.avionTierra:
        return 'avion_tierra';
      case TravelerType.soloTierra:
        return 'solo_tierra';
    }
  }

  static TravelerType? fromApiValue(String? value) {
    switch (value) {
      case 'avion_ida_vuelta':
        return TravelerType.avionIdaVuelta;
      case 'avion_tierra':
        return TravelerType.avionTierra;
      case 'solo_tierra':
        return TravelerType.soloTierra;
      default:
        return null;
    }
  }
}
