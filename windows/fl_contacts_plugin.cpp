#include "fl_contacts_plugin.h"

// Must be included before many other Windows headers.
#include <windows.h>

#include <shellapi.h>

#include <winrt/Windows.ApplicationModel.Contacts.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <cstdint>
#include <map>
#include <memory>
#include <sstream>
#include <thread>
#include <vector>

namespace fl_contacts {

namespace contacts = winrt::Windows::ApplicationModel::Contacts;
namespace foundation = winrt::Windows::Foundation;
namespace streams = winrt::Windows::Storage::Streams;

namespace {

constexpr char kChannelName[] = "github.com/QuisApp/fl_contacts";
constexpr char kEventsChannel[] = "github.com/QuisApp/fl_contacts/events";
constexpr char kChangesChannel[] =
    "github.com/QuisApp/fl_contacts/contactChanges";

using Map = flutter::EncodableMap;
using List = flutter::EncodableList;
using Value = flutter::EncodableValue;

std::string ToUtf8(const winrt::hstring &s) { return winrt::to_string(s); }

std::string GetString(const Map &m, const char *key) {
  auto it = m.find(Value(key));
  if (it == m.end()) return "";
  auto *s = std::get_if<std::string>(&it->second);
  return s ? *s : "";
}

const List *GetList(const Map &m, const char *key) {
  auto it = m.find(Value(key));
  if (it == m.end()) return nullptr;
  return std::get_if<List>(&it->second);
}

const Map *GetMapArg(const Value &args, size_t index) {
  auto *list = std::get_if<List>(&args);
  if (!list || index >= list->size()) return nullptr;
  return std::get_if<Map>(&(*list)[index]);
}

std::string PhoneLabel(contacts::ContactPhoneKind kind) {
  using Kind = contacts::ContactPhoneKind;
  switch (kind) {
    case Kind::Home:
      return "home";
    case Kind::Mobile:
      return "mobile";
    case Kind::Work:
      return "work";
    default:
      return "custom";
  }
}

std::string EmailLabel(contacts::ContactEmailKind kind) {
  using Kind = contacts::ContactEmailKind;
  switch (kind) {
    case Kind::Personal:
      return "home";
    case Kind::Work:
      return "work";
    default:
      return "other";
  }
}

std::string AddressLabel(contacts::ContactAddressKind kind) {
  using Kind = contacts::ContactAddressKind;
  switch (kind) {
    case Kind::Home:
      return "home";
    case Kind::Work:
      return "work";
    default:
      return "other";
  }
}

// Reads up to 8 MiB from a stream reference; empty on any failure.
std::vector<uint8_t> ReadStreamBytes(
    winrt::Windows::Storage::Streams::IRandomAccessStreamReference ref) {
  try {
    auto stream = ref.OpenReadAsync().get();
    uint64_t size = stream.Size();
    if (size == 0 || size > 8 * 1024 * 1024) return {};
    streams::Buffer buffer(static_cast<uint32_t>(size));
    stream.ReadAsync(buffer, static_cast<uint32_t>(size),
                     streams::InputStreamOptions::None)
        .get();
    uint8_t *data = buffer.data();
    return std::vector<uint8_t>(data, data + buffer.Length());
  } catch (...) {
    return {};
  }
}

Value BytesValue(const std::vector<uint8_t> &bytes) {
  return Value(std::vector<uint8_t>(bytes));
}

Map PhoneMap(const std::string &number, const std::string &label) {
  return Map{
      {Value("number"), Value(number)},
      {Value("normalizedNumber"), Value("")},
      {Value("label"), Value(label)},
      {Value("customLabel"), Value("")},
      {Value("isPrimary"), Value(false)},
  };
}

Map ContactToMap(const contacts::Contact &c, bool withPhoto) {
  Map m;
  m[Value("id")] = Value(ToUtf8(c.Id()));
  m[Value("displayName")] = Value(ToUtf8(c.DisplayName()));
  m[Value("isStarred")] = Value(false);
  Map name;
  name[Value("first")] = Value(ToUtf8(c.FirstName()));
  name[Value("last")] = Value(ToUtf8(c.LastName()));
  name[Value("middle")] = Value(ToUtf8(c.MiddleName()));
  name[Value("prefix")] = Value(ToUtf8(c.HonorificNamePrefix()));
  name[Value("suffix")] = Value(ToUtf8(c.HonorificNameSuffix()));
  name[Value("nickname")] = Value(ToUtf8(c.Nickname()));
  name[Value("firstPhonetic")] = Value("");
  name[Value("lastPhonetic")] = Value("");
  name[Value("middlePhonetic")] = Value("");
  m[Value("name")] = Value(name);
  List phones;
  for (auto phone : c.Phones()) {
    phones.push_back(Value(PhoneMap(ToUtf8(phone.Number()),
                                     PhoneLabel(phone.Kind()))));
  }
  m[Value("phones")] = Value(phones);
  List emails;
  for (auto email : c.Emails()) {
    Map e;
    e[Value("address")] = Value(ToUtf8(email.Address()));
    e[Value("label")] = Value(EmailLabel(email.Kind()));
    e[Value("customLabel")] = Value("");
    e[Value("isPrimary")] = Value(false);
    emails.push_back(Value(e));
  }
  m[Value("emails")] = Value(emails);
  List addresses;
  for (auto address : c.Addresses()) {
    Map a;
    a[Value("address")] = Value("");
    a[Value("label")] = Value(AddressLabel(address.Kind()));
    a[Value("customLabel")] = Value("");
    a[Value("street")] = Value(ToUtf8(address.StreetAddress()));
    a[Value("pobox")] = Value("");
    a[Value("neighborhood")] = Value("");
    a[Value("city")] = Value(ToUtf8(address.Locality()));
    a[Value("state")] = Value(ToUtf8(address.Region()));
    a[Value("postalCode")] = Value(ToUtf8(address.PostalCode()));
    a[Value("country")] = Value(ToUtf8(address.Country()));
    a[Value("isoCountry")] = Value("");
    a[Value("subAdminArea")] = Value("");
    a[Value("subLocality")] = Value("");
    addresses.push_back(Value(a));
  }
  m[Value("addresses")] = Value(addresses);
  List orgs;
  {
    auto job = c.JobInfo();
    std::string company = ToUtf8(job.CompanyName());
    std::string title = ToUtf8(job.Title());
    if (!company.empty() || !title.empty()) {
      Map o;
      o[Value("company")] = Value(company);
      o[Value("title")] = Value(title);
      o[Value("department")] = Value(ToUtf8(job.Department()));
      o[Value("jobDescription")] = Value("");
      o[Value("symbol")] = Value("");
      o[Value("phoneticName")] = Value("");
      o[Value("officeLocation")] = Value("");
      orgs.push_back(Value(o));
    }
  }
  m[Value("organizations")] = Value(orgs);
  m[Value("websites")] = Value(List{});
  m[Value("socialMedias")] = Value(List{});
  m[Value("events")] = Value(List{});
  m[Value("notes")] = Value(List{});
  m[Value("accounts")] = Value(List{});
  m[Value("groups")] = Value(List{});
  if (withPhoto) {
    try {
      auto bytes = ReadStreamBytes(c.Thumbnail());
      if (!bytes.empty()) {
        m[Value("photo")] = BytesValue(bytes);
        m[Value("thumbnail")] = BytesValue(bytes);
      }
    } catch (...) {
    }
  }
  return m;
}

const Map *GetMap(const Map &m, const char *key) {
  auto it = m.find(Value(key));
  if (it == m.end()) return nullptr;
  return std::get_if<Map>(&it->second);
}

void ApplyMapToContact(const Map &m, contacts::Contact &c) {
  if (auto *name = GetMap(m, "name")) {
    c.FirstName(winrt::to_hstring(GetString(*name, "first")));
    c.LastName(winrt::to_hstring(GetString(*name, "last")));
    c.MiddleName(winrt::to_hstring(GetString(*name, "middle")));
    c.HonorificNamePrefix(winrt::to_hstring(GetString(*name, "prefix")));
    c.HonorificNameSuffix(winrt::to_hstring(GetString(*name, "suffix")));
    c.Nickname(winrt::to_hstring(GetString(*name, "nickname")));
  }
  c.Phones().Clear();
  if (auto *phones = GetList(m, "phones")) {
    for (auto &p : *phones) {
      auto *pm = std::get_if<Map>(p);
      if (!pm) continue;
      contacts::ContactPhone phone;
      phone.Number(winrt::to_hstring(GetString(*pm, "number")));
      std::string label = GetString(*pm, "label");
      if (label == "mobile")
        phone.Kind(contacts::ContactPhoneKind::Mobile);
      else if (label == "home")
        phone.Kind(contacts::ContactPhoneKind::Home);
      else if (label == "work")
        phone.Kind(contacts::ContactPhoneKind::Work);
      c.Phones().Append(phone);
    }
  }
  c.Emails().Clear();
  if (auto *emails = GetList(m, "emails")) {
    for (auto &e : *emails) {
      auto *em = std::get_if<Map>(e);
      if (!em) continue;
      contacts::ContactEmail email;
      email.Address(winrt::to_hstring(GetString(*em, "address")));
      std::string label = GetString(*em, "label");
      if (label == "work")
        email.Kind(contacts::ContactEmailKind::Work);
      else if (label == "home" || label == "mobile" || label == "iCloud")
        email.Kind(contacts::ContactEmailKind::Personal);
      else
        email.Kind(contacts::ContactEmailKind::Other);
      c.Emails().Append(email);
    }
  }
  if (auto *orgs = GetList(m, "organizations")) {
    if (!orgs->empty()) {
      if (auto *om = std::get_if<Map>(&(*orgs)[0])) {
        auto job = c.JobInfo();
        job.CompanyName(winrt::to_hstring(GetString(*om, "company")));
        job.Title(winrt::to_hstring(GetString(*om, "title")));
        job.Department(winrt::to_hstring(GetString(*om, "department")));
      }
    }
  }
}

}  // namespace

FlContactsPlugin::FlContactsPlugin() {
  try {
    winrt::init_apartment();
  } catch (...) {
  }
}

FlContactsPlugin::~FlContactsPlugin() { StopPolling(); }

// static
void FlContactsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  auto events =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), kEventsChannel,
          &flutter::StandardMethodCodec::GetInstance());
  auto changes =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChangesChannel,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlContactsPlugin>();
  plugin->registrar_ = registrar;

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  events->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [plugin_pointer = plugin.get()](
              const flutter::EncodableValue *arguments,
              std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
                  &&events) {
            (void)arguments;
            plugin_pointer->SetLegacySink(std::move(events));
            return nullptr;
          },
          [plugin_pointer = plugin.get()](
              const flutter::EncodableValue *arguments) {
            (void)arguments;
            plugin_pointer->SetLegacySink(nullptr);
            return nullptr;
          }));
  changes->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [plugin_pointer = plugin.get()](
              const flutter::EncodableValue *arguments,
              std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
                  &&events) {
            return plugin_pointer->OnListenInternal(arguments,
                                                    std::move(events));
          },
          [plugin_pointer = plugin.get()](
              const flutter::EncodableValue *arguments) {
            return plugin_pointer->OnCancelInternal(arguments);
          }));

  registrar->AddPlugin(std::move(plugin));
}

static contacts::ContactStore OpenStore() {
  return contacts::ContactManager::RequestStoreAsync(
             contacts::ContactStoreAccessType::AppContactsReadWrite)
      .get();
}

static contacts::ContactList DefaultList(contacts::ContactStore &store) {
  auto lists = store.FindContactListsAsync().get();
  if (lists.Size() > 0) return lists.GetAt(0);
  return store.CreateContactListAsync(winrt::hstring(L"Contacts")).get();
}

static void RunBackground(std::function<void()> work) {
  std::thread([work = std::move(work)]() {
    try {
      winrt::init_apartment();
    } catch (...) {
    }
    work();
  }).detach();
}

void FlContactsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();
  // Copy arguments; the call object dies on return.
  flutter::EncodableValue args = method_call.arguments()
                                     ? *method_call.arguments()
                                     : flutter::EncodableValue();

  auto fail = [&result](const std::string &message) {
    result->Error("fl_contacts_error", message);
  };

  if (method == "requestPermission") {
    RunBackground([result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        OpenStore();
        result->Success(Value(true));
      } catch (...) {
        result->Success(Value(false));
      }
    });
    return;
  }
  if (method == "checkPermissionStatus") {
    RunBackground([result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        OpenStore();
        result->Success(Value("granted"));
      } catch (...) {
        result->Success(Value("denied"));
      }
    });
    return;
  }
  if (method == "select") {
    RunBackground([args = std::move(args),
                   result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        auto *list = std::get_if<List>(&args);
        bool withPhoto = list && list->size() > 3 &&
                         std::get_if<bool>(&(*list)[3]) &&
                         *std::get_if<bool>(&(*list)[3]);
        std::string id;
        if (list && !list->empty()) {
          if (auto *s = std::get_if<std::string>(&(*list)[0])) id = *s;
        }
        auto store = OpenStore();
        List out;
        auto lists = store.FindContactListsAsync().get();
        for (auto cl : lists) {
          auto reader = cl.GetContactReader();
          while (true) {
            auto batch = reader.ReadBatchAsync().get();
            if (batch.Contacts().Size() == 0) break;
            for (auto c : batch.Contacts()) {
              if (!id.empty() &&
                  ToUtf8(c.Id()) != id)
                continue;
              out.push_back(Value(ContactToMap(c, withPhoto)));
              if (!id.empty()) break;
            }
            if (!id.empty() && !out.empty()) break;
          }
          if (!id.empty() && !out.empty()) break;
        }
        result->Success(Value(out));
      } catch (const std::exception &e) {
        fail(e.what());
      } catch (...) {
        fail("select failed");
      }
    });
    return;
  }
  if (method == "insert" || method == "insertAll") {
    RunBackground([args = std::move(args), method,
                   result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        auto store = OpenStore();
        auto list = DefaultList(store);
        std::vector<Map> inputs;
        if (method == "insert") {
          if (auto *m = GetMapArg(args, 0)) inputs.push_back(*m);
        } else if (auto *l = std::get_if<List>(&args)) {
          // insertAll wraps the list once more: [[{...}]].
          const List *inner = l;
          if (!l->empty()) {
            if (auto *nested = std::get_if<List>(&(*l)[0])) inner = nested;
          }
          for (auto &v : *inner) {
            if (auto *m = std::get_if<Map>(&v)) inputs.push_back(*m);
          }
        }
        List out;
        for (auto &m : inputs) {
          if (GetString(m, "id") != "") {
            result->Error("fl_contacts_error",
                          "Cannot insert contact that already has an ID");
            return;
          }
          contacts::Contact c;
          ApplyMapToContact(m, c);
          list.SaveContactAsync(c).get();
          auto saved = store.GetContactAsync(c.Id()).get();
          out.push_back(Value(ContactToMap(saved, true)));
        }
        if (method == "insert") {
          if (out.empty())
            result->Error("fl_contacts_error", "failed to create contact");
          else
            result->Success(out[0]);
        } else {
          result->Success(Value(out));
        }
      } catch (const std::exception &e) {
        fail(e.what());
      } catch (...) {
        fail("insert failed");
      }
    });
    return;
  }
  if (method == "update" || method == "updateAll") {
    RunBackground([args = std::move(args), method,
                   result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        auto store = OpenStore();
        std::vector<Map> inputs;
        if (method == "update") {
          if (auto *m = GetMapArg(args, 0)) inputs.push_back(*m);
        } else if (auto *l = std::get_if<List>(&args)) {
          const List *inner = l;
          if (!l->empty()) {
            if (auto *nested = std::get_if<List>(&(*l)[0])) inner = nested;
          }
          for (auto &v : *inner) {
            if (auto *m = std::get_if<Map>(&v)) inputs.push_back(*m);
          }
        }
        List out;
        for (auto &m : inputs) {
          std::string id = GetString(m, "id");
          if (id.empty()) {
            result->Error("fl_contacts_error",
                          "Cannot update contact without ID");
            return;
          }
          auto existing =
              store.GetContactAsync(winrt::to_hstring(id)).get();
          ApplyMapToContact(m, existing);
          // Persist through the owning list.
          bool saved = false;
          auto lists = store.FindContactListsAsync().get();
          for (auto cl : lists) {
            try {
              auto probe = cl.GetContactReader();
              while (true) {
                auto batch = probe.ReadBatchAsync().get();
                if (batch.Contacts().Size() == 0) break;
                for (auto c : batch.Contacts()) {
                  if (ToUtf8(c.Id()) == id) {
                    cl.SaveContactAsync(existing).get();
                    saved = true;
                    break;
                  }
                }
                if (saved) break;
              }
            } catch (...) {
            }
            if (saved) break;
          }
          if (!saved) {
            result->Error("fl_contacts_error", "contact not found");
            return;
          }
          auto refreshed =
              store.GetContactAsync(winrt::to_hstring(id)).get();
          out.push_back(Value(ContactToMap(refreshed, true)));
        }
        if (method == "update") {
          if (out.empty())
            result->Error("fl_contacts_error", "failed to update contact");
          else
            result->Success(out[0]);
        } else {
          result->Success(Value(out));
        }
      } catch (const std::exception &e) {
        fail(e.what());
      } catch (...) {
        fail("update failed");
      }
    });
    return;
  }
  if (method == "delete") {
    RunBackground([args = std::move(args),
                   result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        auto *list = std::get_if<List>(&args);
        std::vector<std::string> ids;
        if (list) {
          for (auto &v : *list) {
            if (auto *s = std::get_if<std::string>(&v)) ids.push_back(*s);
          }
        }
        auto store = OpenStore();
        auto lists = store.FindContactListsAsync().get();
        for (auto &id : ids) {
          for (auto cl : lists) {
            try {
              auto reader = cl.GetContactReader();
              bool done = false;
              while (!done) {
                auto batch = reader.ReadBatchAsync().get();
                if (batch.Contacts().Size() == 0) break;
                for (auto c : batch.Contacts()) {
                  if (ToUtf8(c.Id()) == id) {
                    cl.DeleteContactAsync(c).get();
                    done = true;
                    break;
                  }
                }
              }
            } catch (...) {
            }
          }
        }
        result->Success(Value());
      } catch (const std::exception &e) {
        fail(e.what());
      } catch (...) {
        fail("delete failed");
      }
    });
    return;
  }
  if (method == "getGroups") {
    RunBackground([result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        auto store = OpenStore();
        auto lists = store.FindContactListsAsync().get();
        List out;
        for (auto cl : lists) {
          Map g;
          g[Value("id")] = Value(ToUtf8(cl.Id()));
          g[Value("name")] = Value(ToUtf8(cl.DisplayName()));
          out.push_back(Value(g));
        }
        result->Success(Value(out));
      } catch (const std::exception &e) {
        fail(e.what());
      } catch (...) {
        fail("getGroups failed");
      }
    });
    return;
  }
  // Contact lists behave like groups: membership is tracked per list, so
  // copies made by addContactsToGroup get fresh IDs (OS semantics).
  if (method == "getGroupsOf") {
    RunBackground([args = std::move(args),
                   result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        std::string id;
        if (auto *list = std::get_if<List>(&args)) {
          if (!list->empty()) {
            if (auto *s = std::get_if<std::string>(&(*list)[0])) id = *s;
          }
        }
        auto store = OpenStore();
        auto lists = store.FindContactListsAsync().get();
        List out;
        for (auto cl : lists) {
          auto reader = cl.GetContactReader();
          bool hit = false;
          while (!hit) {
            auto batch = reader.ReadBatchAsync().get();
            if (batch.Contacts().Size() == 0) break;
            for (auto c : batch.Contacts()) {
              if (ToUtf8(c.Id()) == id) {
                hit = true;
                break;
              }
            }
          }
          if (hit) {
            Map g;
            g[Value("id")] = Value(ToUtf8(cl.Id()));
            g[Value("name")] = Value(ToUtf8(cl.DisplayName()));
            out.push_back(Value(g));
          }
        }
        result->Success(Value(out));
      } catch (const std::exception &e) {
        fail(e.what());
      } catch (...) {
        fail("getGroupsOf failed");
      }
    });
    return;
  }
  if (method == "addContactsToGroup" || method == "removeContactsFromGroup") {
    RunBackground([args = std::move(args), method,
                   result = std::shared_ptr<
                       flutter::MethodResult<flutter::EncodableValue>>(
                       std::move(result))]() mutable {
      try {
        std::string groupId;
        std::vector<std::string> ids;
        if (auto *list = std::get_if<List>(&args)) {
          if (!list->empty()) {
            if (auto *s = std::get_if<std::string>(&(*list)[0])) groupId = *s;
          }
          if (list->size() > 1) {
            if (auto *inner = std::get_if<List>(&(*list)[1])) {
              for (auto &v : *inner) {
                if (auto *s = std::get_if<std::string>(&v)) ids.push_back(*s);
              }
            }
          }
        }
        auto store = OpenStore();
        auto lists = store.FindContactListsAsync().get();
        contacts::ContactList target{nullptr};
        for (auto cl : lists) {
          if (ToUtf8(cl.Id()) == groupId) {
            target = cl;
            break;
          }
        }
        if (method == "addContactsToGroup") {
          if (target) {
            for (auto &id : ids) {
              try {
                auto c = store.GetContactAsync(winrt::to_hstring(id)).get();
                target.SaveContactAsync(c).get();
              } catch (...) {
              }
            }
          }
        } else {
          if (target) {
            auto reader = target.GetContactReader();
            while (true) {
              auto batch = reader.ReadBatchAsync().get();
              if (batch.Contacts().Size() == 0) break;
              for (auto c : batch.Contacts()) {
                std::string cid = ToUtf8(c.Id());
                for (auto &id : ids) {
                  if (cid == id) {
                    try {
                      target.DeleteContactAsync(c).get();
                    } catch (...) {
                    }
                    break;
                  }
                }
              }
            }
          }
        }
        result->Success(Value());
      } catch (const std::exception &e) {
        fail(e.what());
      } catch (...) {
        fail("group membership failed");
      }
    });
    return;
  }
  result->NotImplemented();
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
FlContactsPlugin::OnListenInternal(
    const flutter::EncodableValue *arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events) {
  (void)arguments;
  {
    std::lock_guard<std::mutex> lock(sink_mutex_);
    event_sink_ = std::move(events);
  }
  EnsurePolling();
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
FlContactsPlugin::OnCancelInternal(
    const flutter::EncodableValue *arguments) {
  (void)arguments;
  {
    std::lock_guard<std::mutex> lock(sink_mutex_);
    event_sink_.reset();
  }
  StopPolling();
  return nullptr;
}

void FlContactsPlugin::EnsurePolling() {
  bool expected = false;
  if (!polling_.compare_exchange_strong(expected, true)) return;
  poll_thread_ = std::thread([this]() {
    try {
      winrt::init_apartment();
    } catch (...) {
    }
    std::map<std::string, bool> known;
    bool first = true;
    while (polling_.load()) {
      try {
        auto store = OpenStore();
        std::map<std::string, bool> current;
        auto lists = store.FindContactListsAsync().get();
        for (auto cl : lists) {
          auto reader = cl.GetContactReader();
          while (true) {
            auto batch = reader.ReadBatchAsync().get();
            if (batch.Contacts().Size() == 0) break;
            for (auto c : batch.Contacts()) current[ToUtf8(c.Id())] = true;
          }
        }
        if (!first) {
          List changes;
          for (auto &[id, _] : current) {
            if (!known.count(id)) {
              Map e;
              e[Value("type")] = Value("added");
              e[Value("contactId")] = Value(id);
              changes.push_back(Value(e));
            }
          }
          for (auto &[id, _] : known) {
            if (!current.count(id)) {
              Map e;
              e[Value("type")] = Value("removed");
              e[Value("contactId")] = Value(id);
              changes.push_back(Value(e));
            }
          }
          if (!changes.empty()) {
            std::lock_guard<std::mutex> lock(sink_mutex_);
            if (event_sink_) event_sink_->Success(Value(changes));
            if (legacy_sink_) legacy_sink_->Success(Value());
          }
        }
        known = std::move(current);
        first = false;
      } catch (...) {
      }
      std::this_thread::sleep_for(std::chrono::seconds(5));
    }
  });
}

void FlContactsPlugin::SetLegacySink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&sink) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  legacy_sink_ = std::move(sink);
}

void FlContactsPlugin::StopPolling() {
  polling_.store(false);
  if (poll_thread_.joinable()) {
    // Never join from the poll thread itself.
    std::thread t([this]() {
      poll_thread_.join();
    });
    t.detach();
  }
}

}  // namespace fl_contacts
