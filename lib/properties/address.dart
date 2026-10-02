import 'package:fl_contacts/config.dart';
import 'package:fl_contacts/vcard.dart';

/// A labeled postal address. Prefer the formatted [address]: it is always
/// rebuilt from parts when the native record only has structured fields.
class Address {
  /// Formatted address, guaranteed present.
  String address;

  /// Label, defaulting to [AddressLabel.home].
  AddressLabel label;

  /// Free-form label used only with [AddressLabel.custom].
  String customLabel;

  /// Street and house number.
  String street;

  /// PO box. Android only.
  String pobox;

  /// Neighborhood. Android only.
  String neighborhood;

  /// City or locality.
  String city;

  /// State, region or county.
  String state;

  /// Postal or ZIP code.
  String postalCode;

  /// Country name.
  String country;

  /// ISO 3166-1 alpha-2 code. iOS only.
  String isoCountry;

  /// Region or county. iOS only.
  String subAdminArea;

  /// Sub-locality detail. iOS only.
  String subLocality;

  /// Creates an address around its formatted text; parts default to empty.
  Address(
    this.address, {
    this.label = AddressLabel.home,
    this.customLabel = '',
    this.street = '',
    this.pobox = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = '',
    this.isoCountry = '',
    this.subAdminArea = '',
    this.subLocality = '',
  });

  /// Decodes an address from its channel map, defaulting unknown labels.
  factory Address.fromJson(Map<String, dynamic> json) => Address(
    (json['address'] as String?) ?? '',
    label: AddressLabel.fromValue(json['label'] as String?, AddressLabel.home),
    customLabel: (json['customLabel'] as String?) ?? '',
    street: (json['street'] as String?) ?? '',
    pobox: (json['pobox'] as String?) ?? '',
    neighborhood: (json['neighborhood'] as String?) ?? '',
    city: (json['city'] as String?) ?? '',
    state: (json['state'] as String?) ?? '',
    postalCode: (json['postalCode'] as String?) ?? '',
    country: (json['country'] as String?) ?? '',
    isoCountry: (json['isoCountry'] as String?) ?? '',
    subAdminArea: (json['subAdminArea'] as String?) ?? '',
    subLocality: (json['subLocality'] as String?) ?? '',
  );

  /// Encodes the address for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'address': address,
    'label': label.value,
    'customLabel': customLabel,
    'street': street,
    'pobox': pobox,
    'neighborhood': neighborhood,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'country': country,
    'isoCountry': isoCountry,
    'subAdminArea': subAdminArea,
    'subLocality': subLocality,
  };

  @override
  int get hashCode => Object.hash(
    address,
    label,
    customLabel,
    street,
    pobox,
    neighborhood,
    city,
    state,
    postalCode,
    country,
    isoCountry,
    subAdminArea,
    subLocality,
  );

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.address == address &&
      other.label == label &&
      other.customLabel == customLabel &&
      other.street == street &&
      other.pobox == pobox &&
      other.neighborhood == neighborhood &&
      other.city == city &&
      other.state == state &&
      other.postalCode == postalCode &&
      other.country == country &&
      other.isoCountry == isoCountry &&
      other.subAdminArea == subAdminArea &&
      other.subLocality == subLocality;

  @override
  String toString() =>
      'Address(address=$address, label=$label, customLabel=$customLabel, '
      'street=$street, pobox=$pobox, neighborhood=$neighborhood, city=$city, '
      'state=$state, postalCode=$postalCode, country=$country, '
      'isoCountry=$isoCountry, subAdminArea=$subAdminArea, '
      'subLocality=$subLocality)';

  /// Emits the address as `ADR`, preferring structured parts.
  List<String> toVCard() {
    var s = 'ADR';
    if (flContactsConfig.vCardVersion == VCardVersion.v3) {
      switch (label) {
        case AddressLabel.home:
          s += ';TYPE=home';
          break;
        case AddressLabel.work:
          s += ';TYPE=work';
          break;
        default:
      }
    } else {
      switch (label) {
        case AddressLabel.home:
          s += ';LABEL=home';
          break;
        case AddressLabel.school:
          s += ';LABEL=school';
          break;
        case AddressLabel.work:
          s += ';LABEL=work';
          break;
        case AddressLabel.other:
          s += ';LABEL=other';
          break;
        case AddressLabel.custom:
          s += ';LABEL="${vCardEncode(customLabel)}"';
          break;
      }
    }
    if (street.isNotEmpty ||
        pobox.isNotEmpty ||
        city.isNotEmpty ||
        state.isNotEmpty ||
        postalCode.isNotEmpty) {
      s +=
          ':${vCardEncode(pobox)};;'
          '${vCardEncode(street)};'
          '${vCardEncode(city)};'
          '${vCardEncode(state)};'
          '${vCardEncode(postalCode)};'
          '${vCardEncode(country)}';
    } else {
      s += ':;;${vCardEncode(address)};;;;';
    }
    return [s];
  }
}

/// Address labels.
///
/// | Label    | Android | iOS |
/// |----------|:-------:|:---:|
/// | home     | ✔       | ✔   |
/// | school   | ⨯       | ✔   |
/// | work     | ✔       | ✔   |
/// | other    | ✔       | ✔   |
/// | custom   | ✔       | ✔   |
/// Address labels across Android and iOS.
enum AddressLabel {
  home('home'),
  school('school'),
  work('work'),
  other('other'),
  custom('custom');

  /// Wire string used on the channel and in JSON.
  final String value;

  /// Creates a label with its wire [value].
  const AddressLabel(this.value);

  /// Parses a wire string, returning [fallback] for unknown values.
  static AddressLabel fromValue(String? value, AddressLabel fallback) =>
      AddressLabel.values.firstWhere(
        (e) => e.value == value,
        orElse: () => fallback,
      );
}
