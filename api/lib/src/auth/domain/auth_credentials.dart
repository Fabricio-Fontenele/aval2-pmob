enum AuthAction { register, login }

class AuthCredentials {
  static const minimumPasswordLength = 8;
  static final _localPart = RegExp(r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$");
  static final _domainLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$');

  final String email;
  final String password;

  const AuthCredentials._(this.email, this.password);

  factory AuthCredentials.validate({
    required Object? email,
    required Object? password,
    required AuthAction action,
  }) {
    final errors = <String, String>{};
    final normalizedEmail = email is String ? email.trim().toLowerCase() : '';
    if (!_isValidEmail(normalizedEmail)) {
      errors['email'] = 'Informe um e-mail válido.';
    }
    if (password is! String || password.trim().isEmpty) {
      errors['password'] = 'Informe a senha.';
    } else if (action == AuthAction.register &&
        password.runes.length < minimumPasswordLength) {
      errors['password'] = 'A senha deve ter pelo menos 8 caracteres.';
    }
    if (errors.isNotEmpty) throw InvalidAuthInput(errors);
    // The checks above guarantee a nonblank String without changing its bytes.
    return AuthCredentials._(normalizedEmail, password as String);
  }

  static bool _isValidEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || email.length > 254) return false;
    final local = parts[0];
    if (local.length > 64 ||
        !_localPart.hasMatch(local) ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..')) {
      return false;
    }
    final labels = parts[1].split('.');
    return labels.length >= 2 &&
        labels.every(
            (label) => label.length <= 63 && _domainLabel.hasMatch(label));
  }
}

class InvalidAuthInput implements Exception {
  final Map<String, String> fields;

  InvalidAuthInput(Map<String, String> fields)
      : fields = Map.unmodifiable(fields);
}
