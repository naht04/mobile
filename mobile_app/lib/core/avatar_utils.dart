import 'package:flutter/material.dart';

String initialsFromName(String? rawName) {
  final name = (rawName ?? '').trim();
  if (name.isEmpty) return '?';

  final parts = name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }

  if (parts.length == 2) {
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  return (parts[0].characters.first +
          parts[1].characters.first +
          parts.last.characters.first)
      .toUpperCase();
}

Widget initialsAvatar(
  String? displayName, {
  double radius = 20,
  Color backgroundColor = const Color(0xFFF8D5E0),
  Color textColor = const Color(0xFF1F1F1F),
  double? fontSize,
}) {
  final initials = initialsFromName(displayName);
  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    child: Text(
      initials,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w700,
        fontSize: fontSize ?? (radius * 0.48),
      ),
    ),
  );
}
