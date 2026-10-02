import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/widgets/avatar_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Circular identity badge: photo when present, gradient initial otherwise.
///
/// Used everywhere a contact appears (lists, details, pickers, headers).
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    required this.displayName,
    this.photo,
    this.radius,
    super.key,
  });

  /// Builds from a full [Contact].
  factory ContactAvatar.fromContact(
    Contact contact, {
    double? radius,
    Key? key,
  }) {
    return ContactAvatar(
      displayName: contact.displayName,
      photo: contact.photoOrThumbnail,
      radius: radius,
      key: key,
    );
  }

  /// Name driving the fallback gradient and initial.
  final String displayName;

  /// Photo bytes; null renders the gradient initial.
  final Uint8List? photo;

  final double? radius;

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(photo!),
      );
    }
    final colors = AvatarPalette.of(displayName);
    final initial = displayName.isNotEmpty ? displayName[0] : '?';
    final size = (radius ?? 20) * 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: (radius ?? 20) * 0.9,
            ),
          ),
        ),
      ),
    );
  }
}
