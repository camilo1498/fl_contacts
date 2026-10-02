/// Editable contact fields bound to the creator/editor form.
///
/// Plain data holder; persistence lives in the editor controller.
class ContactDraft {
  /// Creates a draft, defaulting every field to empty.
  ContactDraft({
    this.first = '',
    this.last = '',
    this.phone = '',
    this.email = '',
  });

  /// Given name.
  String first;

  /// Family name.
  String last;

  /// Raw phone number, empty when untouched.
  String phone;

  /// Raw email address, empty when untouched.
  String email;
}
