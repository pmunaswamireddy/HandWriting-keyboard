import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders a circular avatar with the first letter of the name
/// and a configurable background color.
class ProfileAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const ProfileAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.outfit(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
