enum ShipmentStatusValue {
  pending,
  offered,
  assigned,
  pickedUp,
  inTransit,
  arrived,
  delivered,
}

extension ShipmentStatusValueX on ShipmentStatusValue {
  String get backendValue {
    switch (this) {
      case ShipmentStatusValue.pending:
        return 'pending';
      case ShipmentStatusValue.offered:
        return 'offered';
      case ShipmentStatusValue.assigned:
        return 'assigned';
      case ShipmentStatusValue.pickedUp:
        return 'picked_up';
      case ShipmentStatusValue.inTransit:
        return 'in_transit';
      case ShipmentStatusValue.arrived:
        return 'arrived';
      case ShipmentStatusValue.delivered:
        return 'delivered';
    }
  }
}

ShipmentStatusValue? parseShipmentStatus(String status) {
  switch (status) {
    case 'pending':
      return ShipmentStatusValue.pending;
    case 'offered':
      return ShipmentStatusValue.offered;
    case 'assigned':
      return ShipmentStatusValue.assigned;
    case 'picked_up':
      return ShipmentStatusValue.pickedUp;
    case 'in_transit':
      return ShipmentStatusValue.inTransit;
    case 'arrived':
      return ShipmentStatusValue.arrived;
    case 'delivered':
      return ShipmentStatusValue.delivered;
    default:
      return null;
  }
}
