import '../../../core/api/media_url.dart';

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
  final DateTime? acceptedAt;
  final DateTime? paymentDueAt;
  final DateTime? completedAt;
  final DateTime? disputeDeadlineAt;
  final String? disputeStatus;
  final DateTime createdAt;
  final Trip? trip;
  final BookingSegment? segment;

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
    this.acceptedAt,
    this.paymentDueAt,
    this.completedAt,
    this.disputeDeadlineAt,
    this.disputeStatus,
    required this.createdAt,
    this.trip,
    this.segment,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status']?.toString();
    return Booking(
      id: json['id'],
      tripId: json['tripId'],
      passengerId: json['passengerId'],
      passengerName: json['passenger']?['fullName'] ?? json['passengerName'],
      passengerAvatar: resolveMediaUrl(
          json['passenger']?['profilePhotoUrl']?.toString() ??
              json['passengerAvatar']?.toString()),
      seatCount: json['seats'] ?? json['seatCount'] ?? 1,
      totalPrice: (json['priceTotal'] ?? json['totalPrice'] ?? 0).toDouble(),
      serviceFee:
          (json['commissionAmount'] ?? json['serviceFee'] ?? 0).toDouble(),
      status: _parseStatus(statusRaw),
      qrCode: json['qrCode'],
      pnrCode: json['pnrCode'],
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.parse(json['checkedInAt'])
          : null,
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'])
          : null,
      paymentDueAt: json['paymentDueAt'] != null
          ? DateTime.parse(json['paymentDueAt'])
          : (json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'])
              : null),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      disputeDeadlineAt: json['disputeDeadlineAt'] != null
          ? DateTime.parse(json['disputeDeadlineAt'])
          : null,
      disputeStatus: json['disputeStatus'],
      createdAt: DateTime.parse(json['createdAt']),
      trip: json['trip'] != null ? Trip.fromJson(json['trip']) : null,
      segment: json['segment'] != null
          ? BookingSegment.fromJson(
              Map<String, dynamic>.from(json['segment'] as Map))
          : null,
    );
  }
}

class BookingSegment {
  final String departure;
  final String arrival;
  final double distanceKm;
  final double ratio;
  final double pricePerSeat;

  BookingSegment({
    required this.departure,
    required this.arrival,
    required this.distanceKm,
    required this.ratio,
    required this.pricePerSeat,
  });

  factory BookingSegment.fromJson(Map<String, dynamic> json) {
    return BookingSegment(
      departure: json['departure']?.toString() ?? '',
      arrival: json['arrival']?.toString() ?? '',
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      ratio: (json['ratio'] ?? 0).toDouble(),
      pricePerSeat: (json['pricePerSeat'] ?? 0).toDouble(),
    );
  }
}

enum BookingStatus {
  pending,
  awaitingPayment,
  confirmed,
  checkedIn,
  completed,
  disputed,
  cancelled,
  rejected
}

BookingStatus _parseStatus(String? raw) {
  switch (raw) {
    case 'pending':
      return BookingStatus.pending;
    case 'awaiting_payment':
      return BookingStatus.awaitingPayment;
    case 'confirmed':
      return BookingStatus.confirmed;
    case 'checked_in':
      return BookingStatus.checkedIn;
    case 'completed':
      return BookingStatus.completed;
    case 'disputed':
      return BookingStatus.disputed;
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
  final String? requestedFrom;
  final String? requestedTo;

  CreateBookingRequest({
    required this.tripId,
    required this.seatCount,
    this.requestedFrom,
    this.requestedTo,
  });

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'seats': seatCount,
        if (requestedFrom != null && requestedFrom!.trim().isNotEmpty)
          'requestedFrom': requestedFrom!.trim(),
        if (requestedTo != null && requestedTo!.trim().isNotEmpty)
          'requestedTo': requestedTo!.trim(),
      };
}
