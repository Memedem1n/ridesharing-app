class Vehicle {
  final String id;
  final String userId;
  final String licensePlate;
  final String registrationNumber;
  final String ownershipType;
  final String? ownerFullName;
  final String? ownerRelation;
  final String brand;
  final String model;
  final int year;
  final String? color;
  final int seats;
  final bool hasAc;
  final bool allowsPets;
  final bool allowsSmoking;
  final bool verified;
  final String? registrationImage;
  final DateTime createdAt;

  Vehicle({
    required this.id,
    required this.userId,
    required this.licensePlate,
    required this.registrationNumber,
    required this.ownershipType,
    this.ownerFullName,
    this.ownerRelation,
    required this.brand,
    required this.model,
    required this.year,
    this.color,
    required this.seats,
    required this.hasAc,
    required this.allowsPets,
    required this.allowsSmoking,
    required this.verified,
    this.registrationImage,
    required this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      licensePlate: json['licensePlate'] ?? '',
      registrationNumber: json['registrationNumber'] ?? '',
      ownershipType: json['ownershipType'] ?? 'self',
      ownerFullName: json['ownerFullName'],
      ownerRelation: json['ownerRelation'],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] ?? DateTime.now().year,
      color: json['color'],
      seats: json['seats'] ?? 4,
      hasAc: json['hasAc'] ?? false,
      allowsPets: json['allowsPets'] ?? false,
      allowsSmoking: json['allowsSmoking'] ?? false,
      verified: json['verified'] ?? false,
      registrationImage: json['registrationImage'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
