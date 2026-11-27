import '../config/app_config.dart';

/// Form field validators used across login, signup, and report forms.
///
/// All validators return `null` when the value is fine, otherwise a message
/// that is shown under the field.
class AppValidators {
  AppValidators._();

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
  static final RegExp _phoneRegex = RegExp(r'^\+?[\d\s\-()]{7,}$');
  static final RegExp _studentIdRegex = RegExp(r'^\d{10}$');

  static String? required(String? value, {String label = 'This field'}) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return '$label is required';
    return null;
  }

  // Upper limits. firestore.rules enforces slightly larger values, so a form
  // that passes these checks is never rejected by the database.
  static const int maxName = 60;
  static const int maxItemName = 100;
  static const int maxDescription = 2000;
  static const int maxLocation = 200;
  static const int maxContact = 100;
  static const int maxFreeText = 300;

  static String? requiredMin(
    String? value,
    int minLength, {
    String label = 'This field',
    int? maxLength,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    if (v.length < minLength) {
      return '$label must be at least $minLength characters';
    }
    if (maxLength != null && v.length > maxLength) {
      return '$label must be at most $maxLength characters';
    }
    return null;
  }

  /// For optional fields: empty is fine, but not longer than [maxLength].
  static String? optionalMax(
    String? value,
    int maxLength, {
    String label = 'This field',
  }) {
    final v = value?.trim() ?? '';
    if (v.length > maxLength) {
      return '$label must be at most $maxLength characters';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Like [email] but also enforces `ALLOWED_EMAIL_DOMAINS` (if configured).
  static String? campusEmail(String? value, {List<String>? allowedDomains}) {
    final basic = email(value);
    if (basic != null) return basic;
    return campusEmailError(value!.trim(), allowedDomains: allowedDomains);
  }

  /// Returns a message if [email] is not on one of the allowed domains.
  /// With no configured domains every address is accepted.
  static String? campusEmailError(
    String email, {
    List<String>? allowedDomains,
  }) {
    final allowed = allowedDomains ?? AppConfig.allowedEmailDomains;
    if (allowed.isEmpty) return null;
    final at = email.lastIndexOf('@');
    final domain = at < 0 ? '' : email.substring(at + 1).trim().toLowerCase();
    final ok = allowed.any((d) => domain == d || domain.endsWith('.$d'));
    if (ok) return null;
    return 'Use your university email (${allowed.map((d) => '@$d').join(' or ')})';
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please repeat the password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? displayName(String? value) {
    return requiredMin(value, 2, label: 'Name', maxLength: maxName);
  }

  /// Kyungsung student numbers are 10 digits, e.g. 2020123456.
  static String? studentId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Student ID is required';
    if (!_studentIdRegex.hasMatch(v)) return 'Must be 10 digits (e.g. 2020123456)';
    return null;
  }

  static String? itemName(String? value) {
    return requiredMin(value, 3, label: 'Item name', maxLength: maxItemName);
  }

  static String? description(String? value) {
    return requiredMin(
      value,
      10,
      label: 'Description',
      maxLength: maxDescription,
    );
  }

  static String? location(String? value) {
    final missing = required(value, label: 'Location');
    if (missing != null) return missing;
    return optionalMax(value, maxLocation, label: 'Location');
  }

  static String? contactInfo(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Contact info is required';
    if (!_emailRegex.hasMatch(v) && !_phoneRegex.hasMatch(v)) {
      return 'Enter a valid email or phone number';
    }
    if (v.length > maxContact) {
      return 'Contact info must be at most $maxContact characters';
    }
    return null;
  }
}
