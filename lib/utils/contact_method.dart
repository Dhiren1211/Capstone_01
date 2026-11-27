import 'package:flutter/material.dart';

/// How a reporter prefers to be contacted.
class ContactMethod {
  const ContactMethod(this.value, this.label, this.icon);

  /// Stored in Firestore (`preferredContactMethod`).
  final String value;
  final String label;
  final IconData icon;
}

const List<ContactMethod> contactMethods = [
  ContactMethod('chat', 'In-app chat', Icons.chat_bubble_outline_rounded),
  ContactMethod('email', 'E-mail', Icons.mail_outline_rounded),
  ContactMethod('phone', 'Phone call', Icons.phone_outlined),
];

/// The method for a stored value (unknown values fall back to chat).
ContactMethod contactMethodOf(String value) => contactMethods.firstWhere(
  (m) => m.value == value,
  orElse: () => contactMethods.first,
);
