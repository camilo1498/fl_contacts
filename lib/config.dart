/// vCard format used when exporting contacts.
enum VCardVersion {
  /// Version 3.0 (RFC 2426): oldest, widest-supported flavor.
  v3,

  /// Version 4.0 (RFC 6350): modern flavor with richer typing.
  v4,
}

/// Plugin-wide switches. Mutate fields directly; they apply to the next call.
class FlContactsConfig {
  /// Reads and writes notes on iOS 13+. Requires the Apple contacts-notes
  /// entitlement; without it the OS returns empty notes.
  bool includeNotesOnIos13AndAbove = false;

  /// Includes Android contacts that belong to no group. Excluded by default.
  bool includeNonVisibleOnAndroid = false;

  /// Returns merged unified contacts instead of per-account raw contacts.
  bool returnUnifiedContacts = true;

  /// vCard flavor used by [Contact.toVCard]. v3 is the safest default.
  VCardVersion vCardVersion = VCardVersion.v3;
}

/// Shared configuration backing [FlContacts.config].
///
/// Models read this directly so they never depend on the method-channel
/// facade; the facade exposes the same instance to callers.
final flContactsConfig = FlContactsConfig();
