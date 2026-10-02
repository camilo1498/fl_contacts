/// Server-side contact filter for [FlContacts.getContacts].
///
/// Filters run natively instead of in Dart. Matching rules differ slightly
/// per OS: name matches are case-insensitive substrings everywhere; phone
/// and email match partially on Android but only fully on iOS and macOS.
class ContactFilter {
  /// IDs to fetch. Empty matches nothing.
  final List<String>? ids;

  /// Group (iOS/macOS) or label (Android) members to fetch.
  final String? groupId;

  /// Case-insensitive substring of the display name.
  final String? name;

  /// Phone digits. Partial on Android, full match elsewhere.
  final String? phone;

  /// Email address. Partial on Android, full match elsewhere.
  final String? email;

  const ContactFilter._({
    this.ids,
    this.groupId,
    this.name,
    this.phone,
    this.email,
  });

  /// Matches exactly the given contact IDs.
  const ContactFilter.ids(List<String> ids) : this._(ids: ids);

  /// Matches members of the given group or label.
  const ContactFilter.group(String groupId) : this._(groupId: groupId);

  /// Matches display names containing [name], ignoring case.
  const ContactFilter.name(String name) : this._(name: name);

  /// Matches phone numbers containing [phone] (Android) or equal to it.
  const ContactFilter.phone(String phone) : this._(phone: phone);

  /// Matches email addresses containing [email] (Android) or equal to it.
  const ContactFilter.email(String email) : this._(email: email);

  /// Encodes the filter for the channel. Null means unfiltered.
  Map<String, dynamic>? toJson() {
    if (ids == null &&
        groupId == null &&
        name == null &&
        phone == null &&
        email == null) {
      return null;
    }
    return <String, dynamic>{
      'ids': ids,
      'groupId': groupId,
      'name': name,
      'phone': phone,
      'email': email,
    };
  }
}
