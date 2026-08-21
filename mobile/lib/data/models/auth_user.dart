class AuthUser {
  final String id;
  final String email;
  final Map<String, dynamic>? userMetadata;

  const AuthUser({
    required this.id,
    this.email = '',
    this.userMetadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    if (userMetadata != null) 'userMetadata': userMetadata,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    userMetadata: json['userMetadata'] as Map<String, dynamic>?,
  );
}

// User alias for compatibility
typedef User = AuthUser;
