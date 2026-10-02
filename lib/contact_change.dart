/// Granularity of a contact change event.
enum ContactChangeType {
  /// A contact appeared that was not in the previous snapshot.
  added,

  /// A contact disappeared from the previous snapshot.
  removed,

  /// A contact persisted with different content.
  updated,
}

/// One contact change reported by [FlContacts.onContactChanged].
///
/// Changes are computed by diffing snapshots around each native database
/// notification, so events describe contacts, not raw provider rows. Bursts
/// of edits arrive as one list per notification cycle.
class ContactChange {
  /// What happened to the contact.
  final ContactChangeType type;

  /// Stable unified-contact identifier the change refers to.
  final String contactId;

  /// Creates a change event. Both fields are required.
  const ContactChange({required this.type, required this.contactId});

  @override
  bool operator ==(Object other) =>
      other is ContactChange &&
      other.type == type &&
      other.contactId == contactId;

  @override
  int get hashCode => Object.hash(type, contactId);

  @override
  String toString() => 'ContactChange(type=$type, contactId=$contactId)';
}
