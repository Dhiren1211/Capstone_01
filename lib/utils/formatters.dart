import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Date / time formatters used across the app.
class AppFormatters {
  AppFormatters._();

  /// "2h ago", "5m ago", "Yesterday" — used by item cards and notifications.
  static String timeAgo(DateTime dateTime) {
    return timeago.format(dateTime);
  }

  /// "Nov 22, 2023" — used on item detail.
  static String shortDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  /// "Nov 22, 2023 · 3:45 PM" — used on item detail metadata.
  static String shortDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy · h:mm a').format(dateTime);
  }

  /// "2023-11-22" — ISO-ish, used for form labels.
  static String isoDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  /// "Hi Alex" — first name greeting for the home header.
  static String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Mask an email like "a***@example.com"
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final local = parts[0];
    final domain = parts[1];
    final masked = local.length <= 2
        ? '${local[0]}***'
        : '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}';
    return '$masked@$domain';
  }

  /// Mask a phone number like "+1 555-***-1234"
  static String maskPhone(String phone) {
    if (phone.length < 4) return '****';
    return '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}';
  }
}
