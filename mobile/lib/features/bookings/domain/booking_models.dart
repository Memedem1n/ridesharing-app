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
    this.checkedInAt,
    required this.createdAt,
    this.trip,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      tripId: json['tripId'],
      passengerId: json['passengerId'],
      passengerName: json['passenger']?['name'],
      passengerAvatar: json['passenger']?['avatar'],
      seatCount: json['seatCount'],
      totalPrice: (json['totalPrice']).toDouble(),
      serviceFee: (json['serviceFee'] ?? 0).toDouble(),
      status: BookingStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BookingStatus.pending,
      ),
      qrCode: json['qrCode'],
      checkedInAt: json['checkedInAt'] != null ? DateTime.parse(json['checkedInAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      trip: json['trip'] != null ? Trip.fromJson(json['trip']) : null,
    );
  }
}

enum BookingStatus { pending, confirmed, checkedIn, completed, cancelled, rejected }

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
      origin: json['origin'],
      destination: json['destination'],
      departureTime: DateTime.parse(json['departureTime']),
      driverName: json['driver']?['name'] ?? '',
      vehicleName: json['vehicle']?['name'],
      vehiclePlate: json['vehicle']?['plate'],
    );
  }
}

class CreateBookingRequest {
  final String tripId;
  final int seatCount;

  CreateBookingRequest({required this.tripId, required this.seatCount});

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'seatCount': seatCount,
  };
}
