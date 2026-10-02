import Contacts
import ContactsUI
import Flutter
import UIKit

@available(iOS 13.0, *)
/// Plugin front door: method channel, event stream and system UI flows.
public class FlContactsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CNContactViewControllerDelegate, CNContactPickerDelegate {
    private var externalResult: FlutterResult?
    private var contactStoreObserver: NSObjectProtocol?

    /// Wires method and event channels with no view-controller lookup.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "github.com/QuisApp/fl_contacts",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "github.com/QuisApp/fl_contacts/events",
            binaryMessenger: registrar.messenger()
        )
        let changesChannel = FlutterEventChannel(
            name: "github.com/QuisApp/fl_contacts/contactChanges",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlContactsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        changesChannel.setStreamHandler(instance.changesHandler)
    }

    /// Dedicated handler owning the detailed-change tracker lifecycle.
    private let changesHandler = FlContactsChangesHandler()

    /// Top-most controller via the key window's scene; walks presentations.
    private var presentingViewController: UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        let root = keyWindow?.rootViewController
            ?? UIApplication.shared.delegate?.window??.rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Shorthand for malformed-call failures.
    private func flutterError(_ message: String) -> FlutterError {
        FlutterError(code: "fl_contacts", message: message, details: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            DispatchQueue.global(qos: .userInteractive).async {
                CNContactStore().requestAccess(for: .contacts, completionHandler: { (_, _) -> Void in
                    // Limited access (iOS 18+) counts as granted for reads.
                    var granted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
                    if #available(iOS 18.0, *) {
                        granted = granted || CNContactStore.authorizationStatus(for: .contacts) == .limited
                    }
                    let isGranted = granted
                    DispatchQueue.main.async {
                        result(isGranted)
                    }
                })
            }
        case "select":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for select"))
                    }
                    return
                }
                let id = args[0] as? String
                let withProperties = args[1] as? Bool ?? false
                let withThumbnail = args[2] as? Bool ?? false
                let withPhoto = args[3] as? Bool ?? false
                let withGroups = args[4] as? Bool ?? false
                let withAccounts = args[5] as? Bool ?? false
                let returnUnifiedContacts = args[6] as? Bool ?? true
                let includeNotesOnIos13AndAbove = args.count > 8 ? (args[8] as? Bool ?? false) : false
                let filter = args.count > 9 ? (args[9] as? [String: Any]) : nil
                let limit = args.count > 10 ? (args[10] as? Int) : nil
                let contacts = FlContacts.select(
                    id: id,
                    withProperties: withProperties,
                    withThumbnail: withThumbnail,
                    withPhoto: withPhoto,
                    withGroups: withGroups,
                    withAccounts: withAccounts,
                    returnUnifiedContacts: returnUnifiedContacts,
                    includeNotesOnIos13AndAbove: includeNotesOnIos13AndAbove,
                    filter: filter,
                    limit: limit
                )
                DispatchQueue.main.async {
                    result(contacts)
                }
            }
        case "insert":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let c = args[0] as? [String: Any?] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for insert"))
                    }
                    return
                }
                let includeNotesOnIos13AndAbove = args[1] as? Bool ?? false
                do {
                    let contact = try FlContacts.insert(
                        c, includeNotesOnIos13AndAbove
                    )
                    DispatchQueue.main.async {
                        result(contact)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "update":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let c = args[0] as? [String: Any?] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for update"))
                    }
                    return
                }
                let withGroups = args[1] as? Bool ?? false
                let includeNotesOnIos13AndAbove = args[2] as? Bool ?? false
                do {
                    let contact = try FlContacts.update(
                        c, withGroups, includeNotesOnIos13AndAbove
                    )
                    DispatchQueue.main.async {
                        result(contact)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "delete":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let ids = call.arguments as? [String] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for delete"))
                    }
                    return
                }
                do {
                    try FlContacts.delete(ids)
                    DispatchQueue.main.async {
                        result(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "getGroups":
            DispatchQueue.global(qos: .userInteractive).async {
                let groups = FlContacts.getGroups()
                DispatchQueue.main.async {
                    result(groups)
                }
            }
        case "insertGroup":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let g = args[0] as? [String: Any] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for insertGroup"))
                    }
                    return
                }
                do {
                    let group = try FlContacts.insertGroup(g)
                    DispatchQueue.main.async {
                        result(group)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "updateGroup":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let g = args[0] as? [String: Any] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for updateGroup"))
                    }
                    return
                }
                do {
                    let group = try FlContacts.updateGroup(g)
                    DispatchQueue.main.async {
                        result(group)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "deleteGroup":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let g = args[0] as? [String: Any] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for deleteGroup"))
                    }
                    return
                }
                do {
                    try FlContacts.deleteGroup(g)
                    DispatchQueue.main.async {
                        result(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "openExternalViewOrEdit":
            DispatchQueue.main.async {
                guard let args = call.arguments as? [Any?],
                      let id = args[0] as? String,
                      let presenter = self.presentingViewController else {
                    result(self.flutterError("Cannot present the contact view"))
                    return
                }
                let contacts = FlContacts.selectInternal(
                    store: CNContactStore(),
                    id: id,
                    withProperties: true,
                    withThumbnail: true,
                    withPhoto: true,
                    returnUnifiedContacts: true,
                    includeNotesOnIos13AndAbove: false,
                    externalIntent: true
                )
                if let contact = contacts.first {
                    let contactView = CNContactViewController(for: contact)
                    contactView.navigationItem.backBarButtonItem = UIBarButtonItem(
                        title: "Back",
                        style: .plain,
                        target: self,
                        action: #selector(self.contactViewControllerDidCancel)
                    )
                    contactView.delegate = self
                    let navigationController = UINavigationController(rootViewController: contactView)
                    presenter.present(navigationController, animated: true, completion: nil)
                    self.externalResult = result
                } else {
                    result(nil)
                }
            }
        case "openExternalPick":
            DispatchQueue.main.async {
                guard let presenter = self.presentingViewController else {
                    result(self.flutterError("Cannot present the contact picker"))
                    return
                }
                let contactPicker = CNContactPickerViewController()
                contactPicker.delegate = self
                presenter.present(contactPicker, animated: true, completion: nil)
                self.externalResult = result
            }
        case "openExternalInsert":
            DispatchQueue.main.async {
                guard let presenter = self.presentingViewController else {
                    result(self.flutterError("Cannot present the contact creator"))
                    return
                }
                let contact = CNMutableContact()
                let args = call.arguments as? [Any?]
                if args?.count ?? 0 > 0 {
                    let contactData = args![0] as? [String: Any?]
                    if !(contactData?.isEmpty ?? true) {
                        FlContacts.addFieldsToContact(contactData!, contact, false)
                    }
                }
                let contactView = CNContactViewController(forNewContact: contact)
                contactView.navigationItem.backBarButtonItem = UIBarButtonItem(
                    title: "Cancel",
                    style: .plain,
                    target: self,
                    action: #selector(self.contactViewControllerDidCancel)
                )
                contactView.delegate = self
                let navigationController = UINavigationController(rootViewController: contactView)
                presenter.present(navigationController, animated: true, completion: nil)
                self.externalResult = result
            }
        case "insertAll":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let list = args[0] as? [[String: Any?]] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for insertAll"))
                    }
                    return
                }
                let includeNotes = args.count > 1 ? (args[1] as? Bool ?? false) : false
                do {
                    let contacts = try FlContacts.insertAll(list, includeNotes)
                    DispatchQueue.main.async {
                        result(contacts)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "updateAll":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let list = args[0] as? [[String: Any?]] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for updateAll"))
                    }
                    return
                }
                let withGroups = args.count > 1 ? (args[1] as? Bool ?? false) : false
                let includeNotes = args.count > 2 ? (args[2] as? Bool ?? false) : false
                do {
                    let contacts = try FlContacts.updateAll(list, withGroups, includeNotes)
                    DispatchQueue.main.async {
                        result(contacts)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "getSimContacts":
            result(self.notAvailable("SIM contacts are only available on Android"))
        case "getProfile":
            result(self.notAvailable("The profile contact is not available on iOS"))
        case "addContactsToGroup":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let groupId = args[0] as? String,
                      let ids = args[1] as? [String] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for addContactsToGroup"))
                    }
                    return
                }
                do {
                    try FlContacts.addContactsToGroup(groupId: groupId, contactIds: ids)
                    DispatchQueue.main.async {
                        result(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "removeContactsFromGroup":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let groupId = args[0] as? String,
                      let ids = args[1] as? [String] else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for removeContactsFromGroup"))
                    }
                    return
                }
                do {
                    try FlContacts.removeContactsFromGroup(groupId: groupId, contactIds: ids)
                    DispatchQueue.main.async {
                        result(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "unknown error",
                            message: "unknown error",
                            details: error.localizedDescription
                        ))
                    }
                }
            }
        case "getGroupsOf":
            DispatchQueue.global(qos: .userInteractive).async {
                guard let args = call.arguments as? [Any?],
                      let contactId = args[0] as? String else {
                    DispatchQueue.main.async {
                        result(self.flutterError("Invalid arguments for getGroupsOf"))
                    }
                    return
                }
                let groups = FlContacts.getGroupsOf(contactId: contactId)
                DispatchQueue.main.async {
                    result(groups)
                }
            }
        case "checkPermissionStatus":
            let status = CNContactStore.authorizationStatus(for: .contacts)
            switch status {
            case .authorized:
                result("granted")
            case .limited:
                result("limited")
            case .restricted:
                result("restricted")
            default:
                result("denied")
            }
        case "openAppSettings":
            DispatchQueue.main.async {
                guard let url = URL(string: UIApplication.openSettingsURLString),
                      UIApplication.shared.canOpenURL(url) else {
                    result(self.flutterError("Cannot open app settings"))
                    return
                }
                UIApplication.shared.open(url)
                result(nil)
            }
        case "isBlockNumbersAvailable",
             "isBlockedNumber",
             "getBlockedNumbers",
             "blockNumbers",
             "unblockNumbers",
             "openDefaultAppSettings":
            result(self.notAvailable("Blocked numbers are only available on Android"))
        case "getRingtone",
             "getRingtones",
             "pickRingtone",
             "getDefaultRingtone",
             "setDefaultRingtone",
             "playRingtone",
             "stopRingtone":
            result(self.notAvailable("Ringtones are only available on Android"))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Subscribes to store-change notifications with a retained token.
    public func onListen(
        withArguments _: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        contactStoreObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CNContactStoreDidChange,
            object: nil,
            queue: nil,
            using: { _ in events([]) }
        )
        return nil
    }

    /// Removes the retained observer so callbacks stop and deinit is safe.
    public func onCancel(withArguments _: Any?) -> FlutterError? {
        if let observer = contactStoreObserver {
            NotificationCenter.default.removeObserver(observer)
            contactStoreObserver = nil
        }
        return nil
    }

    /// Resolves the pending external-view/edit future and dismisses.
    public func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        if let result = externalResult {
            result(contact?.identifier)
            externalResult = nil
        }
        viewController.dismiss(animated: true, completion: nil)
    }

    /// Resolves cancellation with nil from the back-button path.
    @objc func contactViewControllerDidCancel() {
        if let result = externalResult {
            presentingViewController?.dismiss(animated: true, completion: nil)
            result(nil)
            externalResult = nil
        }
    }

    /// Resolves the pending pick future with the chosen identifier.
    public func contactPicker(_: CNContactPickerViewController, didSelect contact: CNContact) {
        if let result = externalResult {
            result(contact.identifier)
            externalResult = nil
        }
    }

    /// Resolves the pending pick future with nil on cancel.
    public func contactPickerDidCancel(_: CNContactPickerViewController) {
        if let result = externalResult {
            result(nil)
            externalResult = nil
        }
    }

    /// Shorthand for Android-only features called on iOS.
    func notAvailable(_ message: String) -> FlutterError {
        FlutterError(code: "not_available", message: message, details: nil)
    }
}

@available(iOS 13.0, *)
/// Owns one detailed-change tracker per platform subscription.
private class FlContactsChangesHandler: NSObject, FlutterStreamHandler {
    private var tracker: FlContactsTracker?

    public func onListen(
        withArguments _: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        tracker?.stop()
        let tracker = FlContactsTracker(sink: events)
        self.tracker = tracker
        tracker.start()
        return nil
    }

    public func onCancel(withArguments _: Any?) -> FlutterError? {
        tracker?.stop()
        tracker = nil
        return nil
    }
}
