// Booking models for ridesharing app

class Booking {
  final String id;
  final String tripId;
  final String passengerId;
  final String? passengerName;
  final String? passengerAvatar;
  final int seatCount;
  final double totalPrice;
  final double serviceFee;
  final BookingStatus status;
  final String? qrCode;
  final String? pnrCode;
  final DateTime? checkedInAt;
  final DateTime createdAt;
  final Trip? trip;

  Booking({
    required this.id,
    required this.tripId,
    required this.passengerId,
    this.passengerName,
    this.passengerAvatar,
    required this.seatCount,
    required this.totalPrice,
    this.serviceFee = 0,
    this.status = BookingStatus.pending,
    this.qrCode,
    this.pnrCode,
    this.checkedInAt,
    required this.createdAt,
    this.trip,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status']?.toString();
    return Booking(
      id: json['id'],
      tripId: json['tripId'],
      passengerId: json['passengerId'],
      passengerName: json['passenger']?['fullName'] ?? json['passengerName'],
      passengerAvatar: json['passenger']?['profilePhotoUrl'] ?? json['passengerAvatar'],
      seatCount: json['seats'] ?? json['seatCount'] ?? 1,
      totalPrice: (json['priceTotal'] ?? json['totalPrice'] ?? 0).toDouble(),
      serviceFee: (json['commissionAmount'] ?? json['serviceFee'] ?? 0).toDouble(),
      status: _parseStatus(statusRaw),
      qrCode: json['qrCode'],
      pnrCode: json['pnrCode'],
      checkedInAt: json['checkedInAt'] != null ? DateTime.parse(json['checkedInAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      trip: json['trip'] != null ? Trip.fromJson(json['trip']) : null,
    );
  }
}

enum BookingStatus { pending, confirmed, checkedIn, completed, cancelled, rejected }

BookingStatus _parseStatus(String? raw) {
  switch (raw) {
    case 'pending':
      return BookingStatus.pending;
    case 'confirmed':
      return BookingStatus.confirmed;
    case 'checked_in':
      return BookingStatus.checkedIn;
    case 'completed':
      return BookingStatus.completed;
    case 'cancelled_by_passenger':
    case 'cancelled_by_driver':
    case 'cancelled':
    case 'expired':
      return BookingStatus.cancelled;
    case 'rejected':
      return BookingStatus.rejected;
    default:
      return BookingStatus.pending;
  }
}

class Trip {
  final String id;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final String driverName;
  final String? vehicleName;
  final String? vehiclePlate;

  Trip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.driverName,
    this.vehicleName,
    this.vehiclePlate,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      origin: json['departureCity'] ?? json['origin'] ?? '',
      destination: json['arrivalCity'] ?? json['destination'] ?? '',
      departureTime: DateTime.parse(json['departureTime']),
      driverName: json['driver']?['fullName'] ?? json['driverName'] ?? 'Sürücü',
      vehicleName: json['vehicle']?['brand'] ?? json['vehicleName'],
      vehiclePlate: json['vehicle']?['licensePlate'] ?? json['vehiclePlate'],
    );
  }
}

class CreateBookingRequest {
  final String tripId;
  final int seatCount;

  CreateBookingRequest({required this.tripId, required this.seatCount});

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'seats': seatCount,
  };
}
