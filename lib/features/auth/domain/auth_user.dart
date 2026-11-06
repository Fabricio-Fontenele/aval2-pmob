class AuthUser {
  const AuthUser({required this.id});

  final String id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AuthUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
