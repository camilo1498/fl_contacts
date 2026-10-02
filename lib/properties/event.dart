import 'package:fl_contacts/config.dart';

/// A labeled date such as a birthday. Android allows several per contact,
/// iOS a single birthday plus labeled dates.
class Event {
  /// Year, or null for year-less dates such as `--05-25`.
  int? year;

  /// Month, 1–12.
  int month;

  /// Day of month, 1–31.
  int day;

  /// Label, defaulting to [EventLabel.birthday].
  EventLabel label;

  /// Free-form label used only with [EventLabel.custom].
  String customLabel;

  /// Creates an event; month and day are required, the rest defaulted.
  Event({
    this.year,
    required this.month,
    required this.day,
    this.label = EventLabel.birthday,
    this.customLabel = '',
  });

  /// Decodes an event from its channel map; missing month/day become 1.
  factory Event.fromJson(Map<String, dynamic> json) => Event(
    year: json['year'] as int?,
    month: (json['month'] as int?) ?? 1,
    day: (json['day'] as int?) ?? 1,
    label: EventLabel.fromValue(json['label'] as String?, EventLabel.birthday),
    customLabel: (json['customLabel'] as String?) ?? '',
  );

  /// Encodes the event for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'year': year,
    'month': month,
    'day': day,
    'label': label.value,
    'customLabel': customLabel,
  };

  @override
  int get hashCode => Object.hash(year, month, day, label, customLabel);

  @override
  bool operator ==(Object other) =>
      other is Event &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.label == label &&
      other.customLabel == customLabel;

  @override
  String toString() =>
      'Event(year=$year, month=$month, day=$day, label=$label, '
      'customLabel=$customLabel)';

  /// Emits birthdays and anniversaries as `BDAY`/`ANNIVERSARY`.
  List<String> toVCard() {
    if ((flContactsConfig.vCardVersion == VCardVersion.v3 &&
            label == EventLabel.birthday) ||
        (flContactsConfig.vCardVersion == VCardVersion.v4 &&
            (label == EventLabel.birthday ||
                label == EventLabel.anniversary))) {
      final param = label == EventLabel.birthday ? 'BDAY' : 'ANNIVERSARY';
      if (flContactsConfig.vCardVersion == VCardVersion.v3) {
        return [
          '$param:'
              '${year == null ? '0000' : year.toString().padLeft(4, '0')}-'
              '${month.toString().padLeft(2, '0')}-'
              '${day.toString().padLeft(2, '0')}',
        ];
      } else {
        return [
          '$param:'
              '${year == null ? '--' : year.toString().padLeft(4, '0')}'
              '${month.toString().padLeft(2, '0')}'
              '${day.toString().padLeft(2, '0')}',
        ];
      }
    }
    return [];
  }
}

/// Event labels.
///
/// | Label       | Android | iOS |
/// |-------------|:-------:|:---:|
/// | anniversary | ✔       | ✔   |
/// | birthday    | ✔       | ✔   |
/// | other       | ✔       | ✔   |
/// | custom      | ✔       | ✔   |
/// Event labels across Android and iOS.
enum EventLabel {
  anniversary('anniversary'),
  birthday('birthday'),
  other('other'),
  custom('custom');

  /// Wire string used on the channel and in JSON.
  final String value;

  /// Creates a label with its wire [value].
  const EventLabel(this.value);

  /// Parses a wire string, returning [fallback] for unknown values.
  static EventLabel fromValue(String? value, EventLabel fallback) => EventLabel
      .values
      .firstWhere((e) => e.value == value, orElse: () => fallback);
}
