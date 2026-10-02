import 'package:fl_contacts/config.dart';
import 'package:fl_contacts/vcard.dart';

/// A labeled email address.
class Email {
  /// The address itself.
  String address;

  /// Label, defaulting to [EmailLabel.home].
  EmailLabel label;

  /// Free-form label used only with [EmailLabel.custom].
  String customLabel;

  /// Default address for this contact. Android only.
  bool isPrimary;

  /// Creates an address; labels default to home with no custom text.
  Email(
    this.address, {
    this.label = EmailLabel.home,
    this.customLabel = '',
    this.isPrimary = false,
  });

  /// Decodes an address from its channel map, defaulting unknown labels.
  factory Email.fromJson(Map<String, dynamic> json) => Email(
    (json['address'] as String?) ?? '',
    label: EmailLabel.fromValue(json['label'] as String?, EmailLabel.home),
    customLabel: (json['customLabel'] as String?) ?? '',
    isPrimary: (json['isPrimary'] as bool?) ?? false,
  );

  /// Encodes the address for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'address': address,
    'label': label.value,
    'customLabel': customLabel,
    'isPrimary': isPrimary,
  };

  @override
  int get hashCode => Object.hash(address, label, customLabel, isPrimary);

  @override
  bool operator ==(Object other) =>
      other is Email &&
      other.address == address &&
      other.label == label &&
      other.customLabel == customLabel &&
      other.isPrimary == isPrimary;

  @override
  String toString() =>
      'Email(address=$address, label=$label, customLabel=$customLabel, '
      'isPrimary=$isPrimary)';

  /// Emits the address as `EMAIL`, preserving primary status.
  List<String> toVCard() {
    var s = 'EMAIL';
    if (flContactsConfig.vCardVersion == VCardVersion.v3) {
      s += ';TYPE=internet';
    } else {
      switch (label) {
        case EmailLabel.home:
          s += ';TYPE=home';
          break;
        case EmailLabel.work:
          s += ';TYPE=work';
          break;
        default:
      }
    }
    if (isPrimary) {
      if (flContactsConfig.vCardVersion == VCardVersion.v3) {
        s += ',pref';
      } else {
        s += ';PREF=1';
      }
    }
    s += ':${vCardEncode(address)}';
    return [s];
  }
}

/// Email labels.
///
/// | Label    | Android | iOS |
/// |----------|:-------:|:---:|
/// | home     | ✔       | ✔   |
/// | iCloud   | ⨯       | ✔   |
/// | mobile   | ✔       | ⨯   |
/// | school   | ⨯       | ✔   |
/// | work     | ✔       | ✔   |
/// | other    | ✔       | ✔   |
/// | custom   | ✔       | ✔   |
/// Email labels across Android and iOS.
enum EmailLabel {
  home('home'),
  iCloud('iCloud'),
  mobile('mobile'),
  school('school'),
  work('work'),
  other('other'),
  custom('custom');

  /// Wire string used on the channel and in JSON.
  final String value;

  /// Creates a label with its wire [value].
  const EmailLabel(this.value);

  /// Parses a wire string, returning [fallback] for unknown values.
  static EmailLabel fromValue(String? value, EmailLabel fallback) => EmailLabel
      .values
      .firstWhere((e) => e.value == value, orElse: () => fallback);
}
