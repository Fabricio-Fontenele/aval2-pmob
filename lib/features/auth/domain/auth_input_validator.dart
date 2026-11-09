class ValidatedAuthCredentials {
  const ValidatedAuthCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class AuthValidationException implements Exception {
  AuthValidationException(Map<String, String> fields)
    : fields = Map.unmodifiable(fields);

  final Map<String, String> fields;

  String? get emailError => fields['email'];
  String? get passwordError => fields['password'];
  String? get passwordConfirmationError => fields['passwordConfirmation'];

  @override
  String toString() => 'AuthValidationException: $fields';
}

abstract final class AuthInputValidator {
  static const int minimumPasswordLength = 8;
  static const int maxEmailLength = 254;
  static const int maxEmailLocalPartLength = 64;
  static const int maxEmailDomainLabelLength = 63;

  static final RegExp _localPartPattern = RegExp(
    r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$",
  );
  static final RegExp _domainLabelPattern = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$',
  );

  static String normalizeEmail(String? email) {
    return email?.trim().toLowerCase() ?? '';
  }

  static String? validateEmail(String? email) {
    final normalized = normalizeEmail(email);
    if (!_isValidEmail(normalized)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  static String? validateLoginPassword(String? password) {
    if (password == null || password.trim().isEmpty) {
      return 'Informe a senha.';
    }
    return null;
  }

  static String? validateRegistrationPassword(String? password) {
    if (password == null || password.trim().isEmpty) {
      return 'Informe a senha.';
    }
    if (password.runes.length < minimumPasswordLength) {
      return 'A senha deve ter pelo menos $minimumPasswordLength caracteres.';
    }
    return null;
  }

  static String? validatePasswordConfirmation({
    required String? password,
    required String? confirmation,
  }) {
    if (confirmation == null || confirmation.trim().isEmpty) {
      return 'Confirme a senha.';
    }
    if (password != confirmation) {
      return 'A confirmação de senha não confere.';
    }
    return null;
  }

  static ValidatedAuthCredentials validateLogin({
    required String? email,
    required String? password,
  }) {
    final errors = <String, String>{};

    final emailError = validateEmail(email);
    if (emailError != null) {
      errors['email'] = emailError;
    }

    final passwordError = validateLoginPassword(password);
    if (passwordError != null) {
      errors['password'] = passwordError;
    }

    if (errors.isNotEmpty) {
      throw AuthValidationException(errors);
    }

    return ValidatedAuthCredentials(
      email: normalizeEmail(email),
      password: password!,
    );
  }

  static ValidatedAuthCredentials validateRegistration({
    required String? email,
    required String? password,
    required String? passwordConfirmation,
  }) {
    final errors = <String, String>{};

    final emailError = validateEmail(email);
    if (emailError != null) {
      errors['email'] = emailError;
    }

    final passwordError = validateRegistrationPassword(password);
    if (passwordError != null) {
      errors['password'] = passwordError;
    }

    final confirmationError = validatePasswordConfirmation(
      password: password,
      confirmation: passwordConfirmation,
    );
    if (confirmationError != null) {
      errors['passwordConfirmation'] = confirmationError;
    }

    if (errors.isNotEmpty) {
      throw AuthValidationException(errors);
    }

    return ValidatedAuthCredentials(
      email: normalizeEmail(email),
      password: password!,
    );
  }

  static bool _isValidEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || email.length > maxEmailLength) {
      return false;
    }
    final local = parts[0];
    if (local.length > maxEmailLocalPartLength ||
        !_localPartPattern.hasMatch(local) ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..')) {
      return false;
    }
    final labels = parts[1].split('.');
    return labels.length >= 2 &&
        labels.every(
          (label) =>
              label.length <= maxEmailDomainLabelLength &&
              _domainLabelPattern.hasMatch(label),
        );
  }
}
