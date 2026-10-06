class PasswordValidationResult {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;

  PasswordValidationResult({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  bool get isValid =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigit &&
      hasSpecialChar;
}

class PasswordValidator {
  static PasswordValidationResult validate(String password) {
    return PasswordValidationResult(
      hasMinLength: password.length >= 8,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasLowercase: password.contains(RegExp(r'[a-z]')),
      hasDigit: password.contains(RegExp(r'[0-9]')),
      hasSpecialChar: password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    );
  }
}