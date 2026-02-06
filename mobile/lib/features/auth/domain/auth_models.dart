class User {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? profilePhotoUrl;
  final bool isVerified;
  final double ratingAvg;
  final int totalTrips;
  final String? bio;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.profilePhotoUrl,
    this.isVerified = false,
    this.ratingAvg = 0,
    this.totalTrips = 0,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      profilePhotoUrl: json['profilePhotoUrl'],
      isVerified: json['isVerified'] ?? false,
      ratingAvg: (json['ratingAvg'] ?? 0).toDouble(),
      totalTrips: json['totalTrips'] ?? 0,
      bio: json['bio'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'profilePhotoUrl': profilePhotoUrl,
    'isVerified': isVerified,
    'ratingAvg': ratingAvg,
    'totalTrips': totalTrips,
    'bio': bio,
  };
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final User user;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}

class LoginRequest {
  final String identifier; // Backend expects 'identifier' not 'emailOrPhone'
  final String password;

  LoginRequest({required String emailOrPhone, required this.password})
      : identifier = emailOrPhone;

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'password': password,
  };
}

class RegisterRequest {
  final String fullName;
  final String email;
  final String phone;
  final String password;

  RegisterRequest({
    required String name,
    required this.email,
    required this.phone,
    required this.password,
  }) : fullName = name;

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'password': password,
  };
}

class VerifyOtpRequest {
  final String phone;
  final String code;

  VerifyOtpRequest({required this.phone, required this.code});

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'code': code,
  };
}
