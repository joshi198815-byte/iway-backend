enum ShipmentStatusValue {
  published,
  offered,
  assigned,
  pickedUp,
  inTransit,
  inDelivery,
  delivered,
  disputed,
}

extension ShipmentStatusValueX on ShipmentStatusValue {
  String get backendValue {
    switch (this) {
      case ShipmentStatusValue.published:
        return 'published';
      case ShipmentStatusValue.offered:
        return 'offered';
      case ShipmentStatusValue.assigned:
        return 'assigned';
      case ShipmentStatusValue.pickedUp:
        return 'picked_up';
      case ShipmentStatusValue.inTransit:
        return 'in_transit';
      case ShipmentStatusValue.inDelivery:
        return 'in_delivery';
      case ShipmentStatusValue.delivered:
        return 'delivered';
      case ShipmentStatusValue.disputed:
        return 'disputed';
    }
  }
}

ShipmentStatusValue? parseShipmentStatus(String status) {
  switch (status) {
    case 'published':
      return ShipmentStatusValue.published;
    case 'offered':
      return ShipmentStatusValue.offered;
    case 'assigned':
      return ShipmentStatusValue.assigned;
    case 'picked_up':
      return ShipmentStatusValue.pickedUp;
    case 'in_transit':
      return ShipmentStatusValue.inTransit;
    case 'in_delivery':
      return ShipmentStatusValue.inDelivery;
    case 'delivered':
      return ShipmentStatusValue.delivered;
    case 'disputed':
      return ShipmentStatusValue.disputed;
    default:
      return null;
  }
}
