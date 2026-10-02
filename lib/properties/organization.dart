import 'package:fl_contacts/vcard.dart';

/// An employer or affiliation with an optional job title.
class Organization {
  /// Company name.
  String company;

  /// Job title.
  String title;

  /// Department or division.
  String department;

  /// Role description. Android only.
  String jobDescription;

  /// Ticker symbol. Android only.
  String symbol;

  /// Phonetic company name.
  String phoneticName;

  /// Office location. Android only.
  String officeLocation;

  /// Creates an empty organization.
  Organization({
    this.company = '',
    this.title = '',
    this.department = '',
    this.jobDescription = '',
    this.symbol = '',
    this.phoneticName = '',
    this.officeLocation = '',
  });

  /// Decodes an organization from its channel map.
  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
    company: (json['company'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    department: (json['department'] as String?) ?? '',
    jobDescription: (json['jobDescription'] as String?) ?? '',
    symbol: (json['symbol'] as String?) ?? '',
    phoneticName: (json['phoneticName'] as String?) ?? '',
    officeLocation: (json['officeLocation'] as String?) ?? '',
  );

  /// Encodes the organization for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'company': company,
    'title': title,
    'department': department,
    'jobDescription': jobDescription,
    'symbol': symbol,
    'phoneticName': phoneticName,
    'officeLocation': officeLocation,
  };

  @override
  int get hashCode => Object.hash(
    company,
    title,
    department,
    jobDescription,
    symbol,
    phoneticName,
    officeLocation,
  );

  @override
  bool operator ==(Object other) =>
      other is Organization &&
      other.company == company &&
      other.title == title &&
      other.department == department &&
      other.jobDescription == jobDescription &&
      other.symbol == symbol &&
      other.phoneticName == phoneticName &&
      other.officeLocation == officeLocation;

  @override
  String toString() =>
      'Organization(company=$company, title=$title, department=$department, '
      'jobDescription=$jobDescription, symbol=$symbol, '
      'phoneticName=$phoneticName, officeLocation=$officeLocation)';

  /// Emits `ORG`, `TITLE` and `ROLE` when populated.
  List<String> toVCard() {
    var lines = <String>[];
    if (company.isNotEmpty || department.isNotEmpty) {
      var s = 'ORG:${vCardEncode(company)}';
      if (department.isNotEmpty) {
        s += ';${vCardEncode(department)}';
      }
      lines.add(s);
    }
    if (title.isNotEmpty) {
      lines.add('TITLE:${vCardEncode(title)}');
    }
    if (jobDescription.isNotEmpty) {
      lines.add('ROLE:${vCardEncode(jobDescription)}');
    }
    return lines;
  }
}
