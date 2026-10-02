/// Contact access state reported by [FlContacts.checkPermissionStatus].
enum FlPermissionStatus {
  /// The OS granted full access.
  granted,

  /// The OS granted partial access (iOS 18+ limited selection).
  limited,

  /// The user denied access but may still grant it (rationale allowed).
  denied,

  /// Access is blocked by policy or was permanently denied in settings.
  restricted,
}

/// A system ringtone reference from [FlRingtones].
class Ringtone {
  /// Opaque URI identifying the ringtone.
  final String uri;

  /// Human-readable title, when metadata was requested.
  final String title;

  /// Creates a ringtone reference.
  const Ringtone({required this.uri, this.title = ''});

  @override
  bool operator ==(Object other) =>
      other is Ringtone && other.uri == uri && other.title == title;

  @override
  int get hashCode => Object.hash(uri, title);

  @override
  String toString() => 'Ringtone(uri=$uri, title=$title)';
}

/// Ringtone slot for default/pick operations.
enum RingtoneType {
  /// Incoming-call ringtone.
  ringtone('ringtone'),

  /// Notification sound.
  notification('notification'),

  /// Alarm sound.
  alarm('alarm');

  /// Wire string used on the channel.
  final String value;

  /// Creates a slot with its wire [value].
  const RingtoneType(this.value);

  /// Parses a wire string, defaulting to [RingtoneType.ringtone].
  static RingtoneType fromValue(String? value) => RingtoneType.values
      .firstWhere((e) => e.value == value, orElse: () => RingtoneType.ringtone);
}
