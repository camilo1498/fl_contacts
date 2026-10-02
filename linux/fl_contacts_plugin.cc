#include "include/fl_contacts/fl_contacts_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <gtk/gtk.h>

#include <string.h>

#include "fl_contacts_plugin_private.h"

#define FL_CONTACTS(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), fl_contacts_plugin_get_type(), \
                              FlContactsPlugin))

// Evolution Data Server endpoints (verified against the EDS source tree:
// factory path from e-book-client.c, bus names from the .service files,
// method shapes from src/private/org.gnome.evolution.dataserver.*.xml).
#define EDS_SOURCES_BUS "org.gnome.evolution.dataserver.Sources"
#define EDS_SOURCE_MANAGER_PATH "/org/gnome/evolution/dataserver/SourceManager"
#define EDS_IFACE_SOURCE "org.gnome.evolution.dataserver.Source"
#define EDS_FACTORY_BUS "org.gnome.evolution.dataserver.AddressBook"
#define EDS_FACTORY_PATH "/org/gnome/evolution/dataserver/AddressBookFactory"
#define EDS_IFACE_FACTORY "org.gnome.evolution.dataserver.AddressBookFactory"
#define EDS_IFACE_BOOK "org.gnome.evolution.dataserver.AddressBook"
#define EDS_IFACE_VIEW "org.gnome.evolution.dataserver.AddressBookView"
#define EDS_IFACE_OBJECT_MANAGER "org.freedesktop.DBus.ObjectManager"

#define FL_CHANNEL "github.com/QuisApp/fl_contacts"
#define FL_EVENTS_CHANNEL "github.com/QuisApp/fl_contacts/events"
#define FL_CHANGES_CHANNEL "github.com/QuisApp/fl_contacts/contactChanges"

struct _FlContactsPlugin {
  GObject parent_instance;

  FlMethodChannel* method_channel;
  FlEventChannel* legacy_channel;
  FlEventChannel* changes_channel;

  // Cached open book, guarded by session_lock.
  GMutex session_lock;
  gchar* book_bus_name;
  gchar* book_object_path;

  // Live view subscription for contactChanges.
  gchar* view_path;
  gchar* view_bus_name;
  guint view_sub_added;
  guint view_sub_modified;
  guint view_sub_removed;
  FlEventSink* legacy_sink;
  FlEventSink* changes_sink;
  gint changes_listeners;
  gint legacy_listeners;
  GMutex sink_lock;
};

G_DEFINE_TYPE(FlContactsPlugin, fl_contacts_plugin, g_object_get_type())

// ---------------------------------------------------------------------------
// Small FlValue helpers.
// ---------------------------------------------------------------------------

static const gchar* value_get_string(FlValue* value) {
  return fl_value_get_type(value) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(value)
             : NULL;
}

static FlValue* map_get(FlValue* map, const gchar* key) {
  if (fl_value_get_type(map) != FL_VALUE_TYPE_MAP) return NULL;
  return fl_value_lookup_string(map, key);
}

static const gchar* map_get_string(FlValue* map, const gchar* key) {
  FlValue* v = map_get(map, key);
  return v ? value_get_string(v) : NULL;
}

// ---------------------------------------------------------------------------
// EDS session: open the first writable address book found.
// ---------------------------------------------------------------------------

static gboolean eds_call_open_book(GDBusConnection* connection,
                                   const gchar* uid, gchar** out_path,
                                   gchar** out_bus, GError** error) {
  g_autoptr(GDBusProxy) factory = g_dbus_proxy_new_sync(
      connection, G_DBUS_PROXY_FLAGS_NONE, NULL, EDS_FACTORY_BUS,
      EDS_FACTORY_PATH, EDS_IFACE_FACTORY, NULL, error);
  if (!factory) return FALSE;
  g_autoptr(GVariant) res = g_dbus_proxy_call_sync(
      factory, "OpenAddressBook", g_variant_new("(s)", uid),
      G_DBUS_CALL_FLAGS_NONE, -1, NULL, error);
  if (!res) return FALSE;
  g_variant_get(res, "(ss)", out_path, out_bus);
  return TRUE;
}

// Lists source UIDs from the registry object manager.
static GList* eds_list_source_uids(GDBusConnection* connection) {
  g_autoptr(GError) error = NULL;
  g_autoptr(GVariant) res = g_dbus_connection_call_sync(
      connection, EDS_SOURCES_BUS, EDS_SOURCE_MANAGER_PATH,
      EDS_IFACE_OBJECT_MANAGER, "GetManagedObjects", NULL,
      G_VARIANT_TYPE("(a{oa{sa{sv}}})"), G_DBUS_CALL_FLAGS_NONE, -1, NULL,
      &error);
  GList* uids = NULL;
  if (!res) return NULL;
  GVariantIter* objects = NULL;
  g_variant_get(res, "(a{oa{sa{sv}}})", &objects);
  gchar* path = NULL;
  GVariantIter* ifaces = NULL;
  while (g_variant_iter_loop(objects, "{oa{sa{sv}}}", &path, &ifaces)) {
    gchar* iface = NULL;
    GVariantIter* props = NULL;
    gboolean is_source = FALSE;
    const gchar* uid = NULL;
    while (g_variant_iter_loop(ifaces, "{sa{sv}}", &iface, &props)) {
      if (g_strcmp0(iface, EDS_IFACE_SOURCE) == 0) {
        gchar* key = NULL;
        GVariant* val = NULL;
        while (g_variant_iter_loop(props, "{sv}", &key, &val)) {
          if (g_strcmp0(key, "UID") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
            uid = g_variant_get_string(val, NULL);
          }
        }
      }
    }
    if (uid) uids = g_list_prepend(uids, g_strdup(uid));
    (void)is_source;
  }
  g_variant_iter_free(objects);
  return g_list_reverse(uids);
}

// Opens the book on the plugin (cached). Returns FALSE with error set when
// Evolution Data Server is unreachable: callers surface not_available.
static gboolean eds_ensure_book(FlContactsPlugin* self, GError** error) {
  g_mutex_lock(&self->session_lock);
  gboolean cached =
      self->book_bus_name && self->book_object_path;
  g_mutex_unlock(&self->session_lock);
  if (cached) return TRUE;

  g_autoptr(GDBusConnection) connection =
      g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, error);
  if (!connection) return FALSE;

  GList* uids = eds_list_source_uids(connection);
  gboolean opened = FALSE;
  for (GList* l = uids; l && !opened; l = l->next) {
    g_autoptr(GError) open_error = NULL;
    gchar* path = NULL;
    gchar* bus = NULL;
    if (eds_call_open_book(connection, (const gchar*)l->data, &path, &bus,
                           &open_error)) {
      // Verify the book answers.
      g_autoptr(GDBusProxy) book = g_dbus_proxy_new_sync(
          connection, G_DBUS_PROXY_FLAGS_NONE, NULL, bus, path,
          EDS_IFACE_BOOK, NULL, &open_error);
      if (book) {
        g_autoptr(GVariant) props = g_dbus_proxy_call_sync(
            book, "Open", NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL,
            &open_error);
        if (props) {
          g_mutex_lock(&self->session_lock);
          g_free(self->book_bus_name);
          g_free(self->book_object_path);
          self->book_bus_name = bus;
          self->book_object_path = path;
          bus = path = NULL;
          g_mutex_unlock(&self->session_lock);
          opened = TRUE;
        }
      }
    }
    g_free(path);
    g_free(bus);
  }
  g_list_free_full(uids, g_free);
  if (!opened) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_NOT_FOUND,
                "Evolution Data Server address book is not available");
    return FALSE;
  }
  return TRUE;
}

static GDBusProxy* eds_book_proxy(FlContactsPlugin* self, GError** error) {
  if (!eds_ensure_book(self, error)) return NULL;
  g_mutex_lock(&self->session_lock);
  gchar* bus = g_strdup(self->book_bus_name);
  gchar* path = g_strdup(self->book_object_path);
  g_mutex_unlock(&self->session_lock);
  GDBusConnection* connection =
      g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, error);
  if (!connection) {
    g_free(bus);
    g_free(path);
    return NULL;
  }
  GDBusProxy* proxy = g_dbus_proxy_new_sync(
      connection, G_DBUS_PROXY_FLAGS_NONE, NULL, bus, path, EDS_IFACE_BOOK,
      NULL, error);
  g_object_unref(connection);
  g_free(bus);
  g_free(path);
  return proxy;
}

// ---------------------------------------------------------------------------
// vCard text helpers (folding-aware, ASCII-safe).
// ---------------------------------------------------------------------------

// Joins folded lines ("\n " / "\n\t") so values scan linearly.
static gchar* vcard_unfold(const gchar* vcard) {
  GString* out = g_string_new(NULL);
  gboolean fresh_line = TRUE;
  for (const gchar* p = vcard; *p; p++) {
    if (*p == '\n' && (p[1] == ' ' || p[1] == '\t')) {
      p++;
      fresh_line = FALSE;
      continue;
    }
    g_string_append_c(out, *p);
    fresh_line = *p == '\n';
  }
  (void)fresh_line;
  return g_string_free(out, FALSE);
}

// First value of a property (case-insensitive name, unfolded text).
static gchar* vcard_first_value(const gchar* unfolded, const gchar* name) {
  gchar* prefix = g_strdup_printf("\n%s", name);
  const gchar* at = strstr(unfolded, prefix);
  if (!at) {
    size_t n = strlen(name);
    if (g_ascii_strncasecmp(unfolded, name, n) != 0 ||
        (unfolded[n] != ':' && unfolded[n] != ';')) {
      g_free(prefix);
      return NULL;
    }
    at = unfolded - 1;
  }
  g_free(prefix);
  const gchar* colon = strchr(at, ':');
  if (!colon) return NULL;
  const gchar* end = strchr(colon + 1, '\n');
  gsize len = end ? (gsize)(end - colon - 1) : strlen(colon + 1);
  gchar* raw = g_strndup(colon + 1, len);
  if (g_str_has_suffix(raw, "\r")) raw[strlen(raw) - 1] = '\0';
  return raw;
}

// UID of a vCard (never folded in practice; unfolded scan is still safe).
static gchar* vcard_uid(const gchar* vcard) {
  g_autofree gchar* unfolded = vcard_unfold(vcard);
  return vcard_first_value(unfolded, "UID");
}

// Splits CATEGORIES honoring backslash escapes.
static GList* vcard_categories(const gchar* vcard) {
  g_autofree gchar* unfolded = vcard_unfold(vcard);
  g_autofree gchar* raw = vcard_first_value(unfolded, "CATEGORIES");
  GList* out = NULL;
  if (!raw) return NULL;
  GString* cur = g_string_new(NULL);
  for (const gchar* p = raw; *p; p++) {
    if (*p == '\\' && p[1]) {
      g_string_append_c(cur, p[1]);
      p++;
    } else if (*p == ',') {
      gchar* item = g_strstrip(g_string_free(cur, FALSE));
      if (*item) out = g_list_prepend(out, item);
      else g_free(item);
      cur = g_string_new(NULL);
    } else {
      g_string_append_c(cur, *p);
    }
  }
  gchar* item = g_strstrip(g_string_free(cur, FALSE));
  if (*item) out = g_list_prepend(out, item);
  else g_free(item);
  return g_list_reverse(out);
}

static gchar* vcard_with_categories(const gchar* vcard, GList* categories) {
  g_autofree gchar* unfolded = vcard_unfold(vcard);
  GString* joined = g_string_new(NULL);
  for (GList* l = categories; l; l = l->next) {
    if (joined->len) g_string_append_c(joined, ',');
    const gchar* s = (const gchar*)l->data;
    for (; *s; s++) {
      if (*s == ',' || *s == '\\') g_string_append_c(joined, '\\');
      g_string_append_c(joined, *s);
    }
  }
  gchar* replacement =
      g_strdup_printf("CATEGORIES:%s", joined->str);
  g_string_free(joined, TRUE);
  // Replace an existing line or append before END:VCARD.
  gchar* start = strstr(unfolded, "\nCATEGORIES:");
  if (!start && g_ascii_strncasecmp(unfolded, "CATEGORIES:", 11) == 0) {
    start = unfolded;
  }
  gchar* out;
  if (start) {
    gchar* end = strchr(start + 1, '\n');
    if (!end) end = start + strlen(start);
    out = g_strdup_printf("%.*s%s%s", (int)(start - unfolded + 1), unfolded,
                          replacement, (*end ? end : ""));
  } else {
    gchar* endmark = strstr(unfolded, "END:VCARD");
    if (endmark) {
      out = g_strdup_printf("%.*s%s\n%s", (int)(endmark - unfolded), unfolded,
                            replacement, endmark);
    } else {
      out = g_strdup_printf("%s\n%s\n", unfolded, replacement);
    }
  }
  g_free(replacement);
  return out;
}

// Lower-cased digit soup used for phone matching.
static gchar* digits_of(const gchar* s) {
  GString* out = g_string_new(NULL);
  for (; *s; s++) {
    if (g_ascii_isdigit(*s)) g_string_append_c(out, *s);
  }
  return g_string_free(out, FALSE);
}

// ---------------------------------------------------------------------------
// Response marshaling back to the main thread.
// ---------------------------------------------------------------------------

typedef struct {
  FlMethodCall* call;
  FlMethodResponse* response;
} CallResult;

static gboolean respond_in_main(gpointer data) {
  CallResult* cr = (CallResult*)data;
  fl_method_call_respond(cr->call, cr->response, NULL);
  g_clear_object(&cr->call);
  g_clear_object(&cr->response);
  g_free(cr);
  return G_SOURCE_REMOVE;
}

static void respond_success(FlMethodCall* call, FlValue* result) {
  CallResult* cr = g_new0(CallResult, 1);
  cr->call = g_object_ref(call);
  cr->response = fl_method_success_response_new(result);
  g_main_context_invoke(NULL, respond_in_main, cr);
}

static void respond_error(FlMethodCall* call, const gchar* code,
                          const gchar* message) {
  CallResult* cr = g_new0(CallResult, 1);
  cr->call = g_object_ref(call);
  cr->response = fl_method_error_response_new(code, message, NULL);
  g_main_context_invoke(NULL, respond_in_main, cr);
}

static void respond_not_implemented(FlMethodCall* call) {
  CallResult* cr = g_new0(CallResult, 1);
  cr->call = g_object_ref(call);
  cr->response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  g_main_context_invoke(NULL, respond_in_main, cr);
}

// Packs one EDS vCard for Dart: {uid, vcard}.
static FlValue* pack_card(const gchar* uid, const gchar* vcard) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "uid", fl_value_new_string(uid ? uid : ""));
  fl_value_set_string_take(map, "vcard", fl_value_new_string(vcard ? vcard : ""));
  return FL_VALUE(g_object_ref(map));
}

// ---------------------------------------------------------------------------
// Worker implementations (blocking D-Bus, never on the UI thread).
// ---------------------------------------------------------------------------

static void worker_select(FlContactsPlugin* self, FlMethodCall* call,
                          FlValue* filter, gint limit) {
  const gchar* f_ids = NULL;
  (void)f_ids;
  GList* want_ids = NULL;
  const gchar* want_group = NULL;
  gchar* want_name = NULL;
  gchar* want_phone = NULL;
  gchar* want_email = NULL;
  if (filter && fl_value_get_type(filter) == FL_VALUE_TYPE_MAP) {
    FlValue* ids = map_get(filter, "ids");
    if (ids && fl_value_get_type(ids) == FL_VALUE_TYPE_LIST) {
      size_t n = fl_value_get_length(ids);
      for (size_t i = 0; i < n; i++) {
        const gchar* s = value_get_string(fl_value_index(ids, i));
        if (s) want_ids = g_list_prepend(want_ids, g_strdup(s));
      }
    }
    want_group = map_get_string(filter, "groupId");
    const gchar* n = map_get_string(filter, "name");
    if (n) want_name = g_utf8_casefold(n, -1);
    const gchar* p = map_get_string(filter, "phone");
    if (p) want_phone = digits_of(p);
    const gchar* e = map_get_string(filter, "email");
    if (e) want_email = g_utf8_casefold(e, -1);
  }

  g_autoptr(GError) error = NULL;
  GDBusProxy* book = eds_book_proxy(self, &error);
  if (!book) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "address book unavailable");
    goto done;
  }
  {
    g_autoptr(GVariant) res = NULL;
    if (want_ids) {
      // Fetch exactly the requested UIDs.
      g_autoptr(FlValue) out = fl_value_new_list();
      for (GList* l = want_ids; l; l = l->next) {
        g_autoptr(GError) get_error = NULL;
        g_autoptr(GVariant) one = g_dbus_proxy_call_sync(
            book, "GetContact", g_variant_new("(s)", (gchar*)l->data),
            G_DBUS_CALL_FLAGS_NONE, -1, NULL, &get_error);
        if (one) {
          const gchar* vcard = NULL;
          g_variant_get(one, "(&s)", &vcard);
          fl_value_append_take(out, pack_card((gchar*)l->data, vcard));
        }
      }
      respond_success(call, out);
      g_object_unref(book);
      goto done;
    }
    res = g_dbus_proxy_call_sync(book, "GetContactList",
                                 g_variant_new("(s)", ""),
                                 G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
    g_object_unref(book);
    if (!res) {
      respond_error(call, "eds_unavailable",
                    error ? error->message : "query failed");
      goto done;
    }
    g_autoptr(FlValue) out = fl_value_new_list();
    GVariantIter* iter = NULL;
    const gchar* vcard = NULL;
    g_variant_get(res, "(as)", &iter);
    gint count = 0;
    while (g_variant_iter_loop(iter, "&s", &vcard)) {
      if (limit >= 0 && count >= limit) break;
      if (want_group) {
        GList* cats = vcard_categories(vcard);
        gboolean hit = FALSE;
        for (GList* c = cats; c; c = c->next) {
          if (g_strcmp0((gchar*)c->data, want_group) == 0) hit = TRUE;
        }
        g_list_free_full(cats, g_free);
        if (!hit) continue;
      }
      if (want_name) {
        g_autofree gchar* unfolded = vcard_unfold(vcard);
        g_autofree gchar* fn = vcard_first_value(unfolded, "FN");
        g_autofree gchar* folded = fn ? g_utf8_casefold(fn, -1) : g_strdup("");
        if (!strstr(folded, want_name)) continue;
      }
      if (want_phone && *want_phone) {
        g_autofree gchar* unfolded = vcard_unfold(vcard);
        gboolean hit = FALSE;
        const gchar* at = unfolded;
        while ((at = strstr(at, "\nTEL")) || (at == unfolded && !strncmp(at, "TEL", 3))) {
          const gchar* colon = strchr(at, ':');
          const gchar* end = colon ? strchr(colon, '\n') : NULL;
          g_autofree gchar* digits = NULL;
          if (colon) {
            gchar* raw = g_strndup(colon + 1, end ? (gsize)(end - colon - 1) : strlen(colon + 1));
            digits = digits_of(raw);
            g_free(raw);
          }
          if (digits && strstr(digits, want_phone)) {
            hit = TRUE;
            break;
          }
          at = colon ? colon + 1 : at + 4;
        }
        if (!hit) continue;
      }
      if (want_email) {
        g_autofree gchar* unfolded = vcard_unfold(vcard);
        gboolean hit = FALSE;
        const gchar* at = unfolded;
        while ((at = strstr(at, "\nEMAIL")) || (at == unfolded && !strncmp(at, "EMAIL", 5))) {
          const gchar* colon = strchr(at, ':');
          const gchar* end = colon ? strchr(colon, '\n') : NULL;
          gchar* raw = g_strndup(colon + 1, end ? (gsize)(end - colon - 1) : strlen(colon + 1));
          gchar* folded = g_utf8_casefold(raw, -1);
          if (strstr(folded, want_email)) hit = TRUE;
          g_free(raw);
          g_free(folded);
          if (hit) break;
          at = colon ? colon + 1 : at + 6;
        }
        if (!hit) continue;
      }
      g_autofree gchar* uid = vcard_uid(vcard);
      fl_value_append_take(out, pack_card(uid ? uid : "", vcard));
      count++;
    }
    g_variant_iter_free(iter);
    respond_success(call, out);
  }
done:
  g_list_free_full(want_ids, g_free);
  g_free(want_name);
  g_free(want_phone);
  g_free(want_email);
}

static void worker_insert(FlContactsPlugin* self, FlMethodCall* call,
                          const gchar* vcard, gboolean batch,
                          GList* vcards) {
  g_autoptr(GError) error = NULL;
  GDBusProxy* book = eds_book_proxy(self, &error);
  if (!book) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "address book unavailable");
    return;
  }
  GPtrArray* in = g_ptr_array_new();
  if (batch) {
    for (GList* l = vcards; l; l = l->next)
      g_ptr_array_add(in, (gpointer)l->data);
  } else if (vcard) {
    g_ptr_array_add(in, (gpointer)vcard);
  }
  g_autoptr(GVariant) res = g_dbus_proxy_call_sync(
      book, "CreateContacts",
      g_variant_new("(asu)", in->pdata, in->len, (guint32)0),
      G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
  g_object_unref(book);
  g_ptr_array_free(in, TRUE);
  if (!res) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "create failed");
    return;
  }
  // Fetch back full cards for stable payloads.
  g_autoptr(FlValue) out = fl_value_new_list();
  GVariantIter* iter = NULL;
  const gchar* uid = NULL;
  g_variant_get(res, "(as)", &iter);
  while (g_variant_iter_loop(iter, "&s", &uid)) {
    g_autoptr(GError) get_error = NULL;
    GDBusProxy* book2 = eds_book_proxy(self, &get_error);
    const gchar* full = "";
    g_autofree gchar* owned = NULL;
    if (book2) {
      g_autoptr(GVariant) one = g_dbus_proxy_call_sync(
          book2, "GetContact", g_variant_new("(s)", uid),
          G_DBUS_CALL_FLAGS_NONE, -1, NULL, &get_error);
      if (one) {
        g_variant_get(one, "(&s)", &full);
        owned = g_strdup(full);
        full = owned;
      }
      g_object_unref(book2);
    }
    fl_value_append_take(out, pack_card(uid, full));
  }
  g_variant_iter_free(iter);
  if (!batch) {
    FlValue* first = fl_value_get_length(out) ? fl_value_index(out, 0) : NULL;
    if (first) {
      respond_success(call, fl_value_ref(first));
    } else {
      respond_error(call, "eds_unavailable", "create produced no contact");
    }
  } else {
    respond_success(call, out);
  }
}

static void worker_update(FlContactsPlugin* self, FlMethodCall* call,
                          const gchar* uid, const gchar* vcard, gboolean batch,
                          GList* pairs) {
  (void)self;
  (void)pairs;
  g_autoptr(GError) error = NULL;
  GDBusProxy* book = eds_book_proxy(self, &error);
  if (!book) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "address book unavailable");
    return;
  }
  GPtrArray* in = g_ptr_array_new();
  if (batch) {
    for (GList* l = pairs; l; l = l->next)
      g_ptr_array_add(in, (gpointer)l->data);
  } else if (vcard) {
    g_ptr_array_add(in, (gpointer)vcard);
  }
  g_autoptr(GVariant) res = g_dbus_proxy_call_sync(
      book, "ModifyContacts",
      g_variant_new("(asu)", in->pdata, in->len, (guint32)0),
      G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
  g_ptr_array_free(in, TRUE);
  if (!res) {
    g_object_unref(book);
    respond_error(call, "eds_unavailable",
                  error ? error->message : "update failed");
    return;
  }
  if (!batch) {
    g_autoptr(GVariant) one = g_dbus_proxy_call_sync(
        book, "GetContact", g_variant_new("(s)", uid),
        G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
    g_object_unref(book);
    if (!one) {
      respond_error(call, "eds_unavailable",
                    error ? error->message : "update produced no contact");
      return;
    }
    const gchar* full = NULL;
    g_variant_get(one, "(&s)", &full);
    respond_success(call, pack_card(uid, full));
  } else {
    g_object_unref(book);
    // Re-fetch every updated card for stable payloads.
    g_autoptr(FlValue) out = fl_value_new_list();
    for (GList* l = pairs; l; l = l->next) {
      const gchar* v = (const gchar*)l->data;
      g_autofree gchar* id = vcard_uid(v);
      fl_value_append_take(out, pack_card(id ? id : "", v));
    }
    respond_success(call, out);
  }
}

static void worker_delete(FlContactsPlugin* self, FlMethodCall* call,
                          GList* uids) {
  g_autoptr(GError) error = NULL;
  GDBusProxy* book = eds_book_proxy(self, &error);
  if (!book) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "address book unavailable");
    return;
  }
  GPtrArray* in = g_ptr_array_new();
  for (GList* l = uids; l; l = l->next) g_ptr_array_add(in, l->data);
  g_autoptr(GVariant) res = g_dbus_proxy_call_sync(
      book, "RemoveContacts",
      g_variant_new("(asu)", in->pdata, in->len, (guint32)0),
      G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
  g_ptr_array_free(in, TRUE);
  g_object_unref(book);
  if (!res) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "delete failed");
    return;
  }
  respond_success(call, fl_value_new_null());
}

// ---------------------------------------------------------------------------
// View subscription for contactChanges.
// ---------------------------------------------------------------------------

typedef struct {
  FlContactsPlugin* plugin;
  FlValue* events;
} ForwardJob;

static gboolean forward_in_main(gpointer data) {
  ForwardJob* job = (ForwardJob*)data;
  g_mutex_lock(&job->plugin->sink_lock);
  FlEventSink* changes = job->plugin->changes_sink
                             ? g_object_ref(job->plugin->changes_sink)
                             : NULL;
  FlEventSink* legacy = job->plugin->legacy_sink
                            ? g_object_ref(job->plugin->legacy_sink)
                            : NULL;
  g_mutex_unlock(&job->plugin->sink_lock);
  if (changes) {
    fl_event_sink_success(changes, job->events);
    g_object_unref(changes);
  }
  if (legacy) {
    fl_event_sink_success(legacy, fl_value_new_null());
    g_object_unref(legacy);
  }
  g_object_unref(job->plugin);
  g_object_unref(job->events);
  g_free(job);
  return G_SOURCE_REMOVE;
}

static void view_signal_cb(GDBusConnection* connection, const gchar* sender,
                           const gchar* path, const gchar* interface,
                           const gchar* signal, GVariant* parameters,
                           gpointer user_data) {
  FlContactsPlugin* self = FL_CONTACTS(user_data);
  (void)connection;
  (void)sender;
  (void)path;
  (void)interface;
  const gchar* type = NULL;
  gboolean want_uids = FALSE;
  if (g_strcmp0(signal, "ObjectsAdded") == 0) {
    type = "added";
  } else if (g_strcmp0(signal, "ObjectsModified") == 0) {
    type = "updated";
  } else if (g_strcmp0(signal, "ObjectsRemoved") == 0) {
    type = "removed";
    want_uids = TRUE;
  } else {
    return;
  }
  FlValue* out = fl_value_new_list();
  GVariantIter* iter = NULL;
  g_variant_get(parameters, "(as)", &iter);
  const gchar* item = NULL;
  while (g_variant_iter_loop(iter, "&s", &item)) {
    g_autofree gchar* uid = NULL;
    if (want_uids) {
      uid = g_strdup(item);
    } else {
      uid = vcard_uid(item);
    }
    FlValue* e = fl_value_new_map();
    fl_value_set_string_take(e, "type", fl_value_new_string(type));
    fl_value_set_string_take(e, "contactId",
                             fl_value_new_string(uid ? uid : ""));
    fl_value_append_take(out, e);
  }
  g_variant_iter_free(iter);
  if (fl_value_get_length(out) == 0) {
    g_object_unref(out);
    return;
  }
  ForwardJob* job = g_new0(ForwardJob, 1);
  job->plugin = (FlContactsPlugin*)g_object_ref(self);
  job->events = out;
  g_main_context_invoke(NULL, forward_in_main, job);
}

// Opens a live view on the cached book; subscribes its change signals.
static gboolean view_subscribe(FlContactsPlugin* self, GError** error) {
  if (self->view_sub_added) return TRUE;
  g_mutex_lock(&self->session_lock);
  gchar* bus = g_strdup(self->book_bus_name);
  gchar* book_path = g_strdup(self->book_object_path);
  g_mutex_unlock(&self->session_lock);
  if (!bus || !book_path) {
    g_free(bus);
    g_free(book_path);
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_NOT_FOUND,
                "no open address book");
    return FALSE;
  }
  g_autoptr(GDBusConnection) connection =
      g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, error);
  if (!connection) {
    g_free(bus);
    g_free(book_path);
    return FALSE;
  }
  g_autoptr(GVariant) res = g_dbus_connection_call_sync(
      connection, bus, book_path, EDS_IFACE_BOOK, "GetView",
      g_variant_new("(s)", ""), G_VARIANT_TYPE("(o)"),
      G_DBUS_CALL_FLAGS_NONE, -1, NULL, error);
  if (!res) {
    g_free(bus);
    g_free(book_path);
    return FALSE;
  }
  const gchar* view_path = NULL;
  g_variant_get(res, "(&o)", &view_path);
  self->view_path = g_strdup(view_path);
  self->view_bus_name = bus;
  bus = NULL;
  g_free(book_path);
  g_dbus_connection_call(
      connection, self->view_bus_name, self->view_path, EDS_IFACE_VIEW,
      "Start", NULL, NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, NULL, NULL);
  self->view_sub_added = g_dbus_connection_signal_subscribe(
      connection, self->view_bus_name, EDS_IFACE_VIEW, "ObjectsAdded",
      self->view_path, NULL, G_DBUS_SIGNAL_FLAGS_NONE, view_signal_cb, self,
      NULL);
  self->view_sub_modified = g_dbus_connection_signal_subscribe(
      connection, self->view_bus_name, EDS_IFACE_VIEW, "ObjectsModified",
      self->view_path, NULL, G_DBUS_SIGNAL_FLAGS_NONE, view_signal_cb, self,
      NULL);
  self->view_sub_removed = g_dbus_connection_signal_subscribe(
      connection, self->view_bus_name, EDS_IFACE_VIEW, "ObjectsRemoved",
      self->view_path, NULL, G_DBUS_SIGNAL_FLAGS_NONE, view_signal_cb, self,
      NULL);
  // The connection must outlive the subscription; the shared default
  // connection is referenced by the subscription itself.
  return TRUE;
}

static void view_unsubscribe(FlContactsPlugin* self) {
  if (!self->view_sub_added) return;
  g_autoptr(GDBusConnection) connection =
      g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, NULL);
  if (connection) {
    g_dbus_connection_signal_unsubscribe(connection, self->view_sub_added);
    g_dbus_connection_signal_unsubscribe(connection, self->view_sub_modified);
    g_dbus_connection_signal_unsubscribe(connection, self->view_sub_removed);
    if (self->view_path) {
      g_dbus_connection_call(
          connection, self->view_bus_name, self->view_path, EDS_IFACE_VIEW,
          "Stop", NULL, NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, NULL, NULL);
      g_dbus_connection_call(
          connection, self->view_bus_name, self->view_path, EDS_IFACE_VIEW,
          "Dispose", NULL, NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, NULL,
          NULL);
    }
  }
  self->view_sub_added = self->view_sub_modified = self->view_sub_removed = 0;
  g_clear_pointer(&self->view_path, g_free);
  g_clear_pointer(&self->view_bus_name, g_free);
}

// ---------------------------------------------------------------------------
// Event stream handlers (GInterface implementations).
// ---------------------------------------------------------------------------

typedef struct _FlStreamHandler FlStreamHandler;
typedef struct {
  GObjectClass parent_class;
} FlStreamHandlerClass;

struct _FlStreamHandler {
  GObject parent_instance;
  FlContactsPlugin* plugin;
  gboolean detailed;
};

typedef struct {
  GObjectClass parent_class;
} FlStreamHandlerClass;

static void stream_listen_locked(FlContactsPlugin* self, FlEventSink* sink,
                                 gboolean detailed);
static void stream_cancel_locked(FlContactsPlugin* self, gboolean detailed);

static FlEventStreamHandlerError* stream_handler_on_listen(
    FlEventStreamHandler* iface, const FlValue* args, FlEventSink* events) {
  (void)args;
  FlStreamHandler* self = (FlStreamHandler*)iface;
  stream_listen_locked(self->plugin, events, self->detailed);
  return nullptr;
}

static FlEventStreamHandlerError* stream_handler_on_cancel(

static FlEventStreamHandlerError* stream_handler_on_cancel(
    FlEventStreamHandler* iface, const FlValue* args) {
  (void)args;
  FlStreamHandler* self = (FlStreamHandler*)iface;
  stream_cancel_locked(self->plugin, self->detailed);
  return nullptr;
}

static void stream_handler_iface_init(FlEventStreamHandlerInterface* iface) {
  iface->on_listen = stream_handler_on_listen;
  iface->on_cancel = stream_handler_on_cancel;
}

G_DEFINE_TYPE_WITH_CODE(FlStreamHandler, fl_stream_handler, G_TYPE_OBJECT,
                        G_IMPLEMENT_INTERFACE(
                            fl_event_stream_handler_get_type(),
                            stream_handler_iface_init))

static void fl_stream_handler_class_init(FlStreamHandlerClass* klass) {
  (void)klass;
}

static void fl_stream_handler_init(FlStreamHandler* self) {
  (void)self;
}

// Listener bookkeeping: the live view runs while either stream is observed.
static void stream_listen_locked(FlContactsPlugin* self, FlEventSink* sink,
                                 gboolean detailed) {
  g_mutex_lock(&self->sink_lock);
  if (detailed) {
    g_clear_object(&self->changes_sink);
    self->changes_sink = (FlEventSink*)g_object_ref(sink);
    self->changes_listeners++;
  } else {
    g_clear_object(&self->legacy_sink);
    self->legacy_sink = (FlEventSink*)g_object_ref(sink);
    self->legacy_listeners++;
  }
  gboolean start = self->changes_listeners + self->legacy_listeners == 1;
  g_mutex_unlock(&self->sink_lock);
  if (start) {
    g_thread_new("fl-view", [](gpointer data) -> gpointer {
      FlContactsPlugin* plugin = FL_CONTACTS(data);
      g_autoptr(GError) error = NULL;
      // Failures stay silent; the next listen retries from scratch.
      if (eds_ensure_book(plugin, &error)) {
        view_subscribe(plugin, &error);
      }
      g_object_unref(plugin);
      return NULL;
    }, g_object_ref(self));
  }
}

static void stream_cancel_locked(FlContactsPlugin* self, gboolean detailed) {
  g_mutex_lock(&self->sink_lock);
  if (detailed) {
    g_clear_object(&self->changes_sink);
    if (self->changes_listeners > 0) self->changes_listeners--;
  } else {
    g_clear_object(&self->legacy_sink);
    if (self->legacy_listeners > 0) self->legacy_listeners--;
  }
  gboolean stop = self->changes_listeners + self->legacy_listeners == 0;
  g_mutex_unlock(&self->sink_lock);
  if (stop) {
    g_thread_new("fl-view-stop", [](gpointer data) -> gpointer {
      view_unsubscribe(FL_CONTACTS(data));
      g_object_unref(data);
      return NULL;
    }, g_object_ref(self));
  }
}

// ---------------------------------------------------------------------------
// Group workers (CATEGORIES-backed labels).
// ---------------------------------------------------------------------------

static void worker_get_groups(FlContactsPlugin* self, FlMethodCall* call) {
  g_autoptr(GError) error = NULL;
  GDBusProxy* book = eds_book_proxy(self, &error);
  if (!book) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "address book unavailable");
    return;
  }
  g_autoptr(GVariant) res = g_dbus_proxy_call_sync(
      book, "GetContactList", g_variant_new("(s)", ""),
      G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
  g_object_unref(book);
  if (!res) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "query failed");
    return;
  }
  GHashTable* seen =
      g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
  GVariantIter* iter = NULL;
  const gchar* vcard = NULL;
  g_variant_get(res, "(as)", &iter);
  while (g_variant_iter_loop(iter, "&s", &vcard)) {
    GList* cats = vcard_categories(vcard);
    for (GList* l = cats; l; l = l->next) {
      if (!g_hash_table_contains(seen, l->data))
        g_hash_table_insert(seen, g_strdup((gchar*)l->data), NULL);
    }
    g_list_free_full(cats, g_free);
  }
  g_variant_iter_free(iter);
  g_autoptr(FlValue) out = fl_value_new_list();
  GHashTableIter hi;
  gpointer key = NULL;
  g_hash_table_iter_init(&hi, seen);
  while (g_hash_table_iter_next(&hi, &key, NULL)) {
    g_autoptr(FlValue) g = fl_value_new_map();
    fl_value_set_string_take(g, "id", fl_value_new_string((gchar*)key));
    fl_value_set_string_take(g, "name", fl_value_new_string((gchar*)key));
    fl_value_append_take(out, g);
  }
  g_hash_table_destroy(seen);
  respond_success(call, out);
}

static void worker_groups_of(FlContactsPlugin* self, FlMethodCall* call,
                             const gchar* uid) {
  g_autoptr(GError) error = NULL;
  GDBusProxy* book = eds_book_proxy(self, &error);
  if (!book) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "address book unavailable");
    return;
  }
  g_autoptr(GVariant) res = g_dbus_proxy_call_sync(
      book, "GetContact", g_variant_new("(s)", uid), G_DBUS_CALL_FLAGS_NONE,
      -1, NULL, &error);
  g_object_unref(book);
  if (!res) {
    respond_success(call, fl_value_new_list());
    return;
  }
  const gchar* vcard = NULL;
  g_variant_get(res, "(&s)", &vcard);
  g_autoptr(FlValue) out = fl_value_new_list();
  GList* cats = vcard_categories(vcard);
  for (GList* l = cats; l; l = l->next) {
    g_autoptr(FlValue) g = fl_value_new_map();
    fl_value_set_string_take(g, "id", fl_value_new_string((gchar*)l->data));
    fl_value_set_string_take(g, "name", fl_value_new_string((gchar*)l->data));
    fl_value_append_take(out, g);
  }
  g_list_free_full(cats, g_free);
  respond_success(call, out);
}

// Rewrites the CATEGORIES of every listed contact.
static void worker_set_membership(FlContactsPlugin* self, FlMethodCall* call,
                                 const gchar* group, GList* uids,
                                 gboolean add) {
  g_autoptr(GError) error = NULL;
  GDBusProxy* book = eds_book_proxy(self, &error);
  if (!book) {
    respond_error(call, "eds_unavailable",
                  error ? error->message : "address book unavailable");
    return;
  }
  for (GList* l = uids; l; l = l->next) {
    g_autoptr(GError) get_error = NULL;
    g_autoptr(GVariant) res = g_dbus_proxy_call_sync(
        book, "GetContact", g_variant_new("(s)", (gchar*)l->data),
        G_DBUS_CALL_FLAGS_NONE, -1, NULL, &get_error);
    if (!res) continue;
    const gchar* vcard = NULL;
    g_variant_get(res, "(&s)", &vcard);
    GList* cats = vcard_categories(vcard);
    gboolean has = FALSE;
    for (GList* c = cats; c; c = c->next) {
      if (g_strcmp0((gchar*)c->data, group) == 0) {
        has = TRUE;
        break;
      }
    }
    if ((add && !has) || (!add && has)) {
      GList* next = NULL;
      if (add) {
        next = g_list_copy_deep(cats, (GCopyFunc)g_strdup, NULL);
        next = g_list_append(next, g_strdup(group));
      } else {
        for (GList* c = cats; c; c = c->next) {
          if (g_strcmp0((gchar*)c->data, group) != 0)
            next = g_list_append(next, g_strdup((gchar*)c->data));
        }
      }
      g_autofree gchar* updated = vcard_with_categories(vcard, next);
      g_autoptr(GError) mod_error = NULL;
      g_dbus_proxy_call_sync(
          book, "ModifyContacts",
          g_variant_new("(asu)", (const gchar*[]){updated}, 1, (guint32)0),
          G_DBUS_CALL_FLAGS_NONE, -1, NULL, &mod_error);
      g_list_free_full(next, g_free);
    }
    g_list_free_full(cats, g_free);
  }
  g_object_unref(book);
  respond_success(call, fl_value_new_null());
}

// ---------------------------------------------------------------------------
// Method dispatch (main thread) -> workers.
// ---------------------------------------------------------------------------

static void fl_contacts_plugin_handle_method_call(FlContactsPlugin* self,
                                                   FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "requestPermission") == 0 ||
      strcmp(method, "checkPermissionStatus") == 0) {
    // Probe EDS off-thread; reachable means granted.
    g_object_ref(method_call);
    g_thread_new(
        "fl-probe",
        [](gpointer data) -> gpointer {
          FlMethodCall* call = (FlMethodCall*)data;
          g_autoptr(GError) error = NULL;
          g_autoptr(GDBusConnection) c =
              g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
          gboolean ok = c != NULL;
          if (ok) {
            g_autoptr(GError) query_error = NULL;
            g_autoptr(GVariant) res = g_dbus_connection_call_sync(
                c, EDS_SOURCES_BUS, EDS_SOURCE_MANAGER_PATH,
                EDS_IFACE_OBJECT_MANAGER, "GetManagedObjects", NULL,
                G_VARIANT_TYPE("(a{oa{sa{sv}}})"), G_DBUS_CALL_FLAGS_NONE, -1,
                NULL, &query_error);
            ok = res != NULL;
          }
          const gchar* probed = fl_method_call_get_name(call);
          CallResult* cr = g_new0(CallResult, 1);
          cr->call = call;
          if (g_strcmp0(probed, "requestPermission") == 0) {
            cr->response =
                fl_method_success_response_new(fl_value_new_bool(ok));
          } else {
            cr->response = fl_method_success_response_new(
                fl_value_new_string(ok ? "granted" : "denied"));
          }
          g_main_context_invoke(NULL, respond_in_main, cr);
          return NULL;
        },
        method_call);
    return;
  }
  if (strcmp(method, "select") == 0) {
    // Linux select takes a trimmed payload: [filterJson?, limit?].
    FlValue* filter = NULL;
    gint limit = -1;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_LIST) {
      if (fl_value_get_length(args) > 0) {
        FlValue* f = fl_value_index(args, 0);
        if (f && fl_value_get_type(f) == FL_VALUE_TYPE_MAP) filter = f;
      }
      if (fl_value_get_length(args) > 1) {
        FlValue* l = fl_value_index(args, 1);
        if (l && fl_value_get_type(l) == FL_VALUE_TYPE_INT)
          limit = (gint)fl_value_get_int(l);
      }
    }
    struct SelectJob {
      FlContactsPlugin* plugin;
      FlMethodCall* call;
      FlValue* filter;
      gint limit;
    };
    SelectJob* job = g_new0(SelectJob, 1);
    job->plugin = (FlContactsPlugin*)g_object_ref(self);
    job->call = (FlMethodCall*)g_object_ref(method_call);
    job->filter = filter ? fl_value_ref(filter) : NULL;
    job->limit = limit;
    g_thread_new(
        "fl-select", [](gpointer data) -> gpointer {
          SelectJob* job = (SelectJob*)data;
          worker_select(job->plugin, job->call, job->filter, job->limit);
          if (job->filter) fl_value_unref(job->filter);
          g_clear_object(&job->call);
          g_object_unref(job->plugin);
          g_free(job);
          return NULL;
        },
        job);
    return;
  }
  if (strcmp(method, "insert") == 0 || strcmp(method, "insertAll") == 0) {
    // Linux insert takes vCard strings: [vcard] or [[vcard,...]].
    GList* vcards = NULL;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_LIST &&
        fl_value_get_length(args) > 0) {
      FlValue* first = fl_value_index(args, 0);
      if (first && fl_value_get_type(first) == FL_VALUE_TYPE_LIST) {
        size_t n = fl_value_get_length(first);
        for (size_t i = 0; i < n; i++) {
          const gchar* s = value_get_string(fl_value_index(first, i));
          if (s) vcards = g_list_prepend(vcards, g_strdup(s));
        }
        vcards = g_list_reverse(vcards);
      } else if (first) {
        const gchar* s = value_get_string(first);
        if (s) vcards = g_list_prepend(vcards, g_strdup(s));
      }
    }
    struct MutJob {
      FlContactsPlugin* plugin;
      FlMethodCall* call;
      GList* vcards;
      gboolean batch;
    };
    MutJob* job = g_new0(MutJob, 1);
    job->plugin = (FlContactsPlugin*)g_object_ref(self);
    job->call = (FlMethodCall*)g_object_ref(method_call);
    job->vcards = vcards;
    job->batch = strcmp(method, "insertAll") == 0;
    g_thread_new(
        "fl-mutate", [](gpointer data) -> gpointer {
          MutJob* job = (MutJob*)data;
          worker_insert(job->plugin, job->call, NULL, job->batch, job->vcards);
          g_list_free_full(job->vcards, g_free);
          g_clear_object(&job->call);
          g_object_unref(job->plugin);
          g_free(job);
          return NULL;
        },
        job);
    return;
  }
  if (strcmp(method, "update") == 0 || strcmp(method, "updateAll") == 0) {
    // Linux update takes [uid, vcard] or [[[uid, vcard], ...]].
    GList* pairs = NULL;
    gchar* single_uid = NULL;
    gchar* single_vcard = NULL;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_LIST &&
        fl_value_get_length(args) > 0) {
      FlValue* first = fl_value_index(args, 0);
      if (first && fl_value_get_type(first) == FL_VALUE_TYPE_LIST &&
          fl_value_get_length(first) > 0 &&
          fl_value_get_type(fl_value_index(first, 0)) ==
              FL_VALUE_TYPE_LIST) {
        size_t n = fl_value_get_length(first);
        for (size_t i = 0; i < n; i++) {
          FlValue* pair = fl_value_index(first, i);
          const gchar* u = value_get_string(fl_value_index(pair, 0));
          const gchar* v = value_get_string(fl_value_index(pair, 1));
          if (u && v) {
            gchar* combined =
                g_strdup_printf("%s\n%s", u, v);
            pairs = g_list_prepend(pairs, combined);
          }
        }
        pairs = g_list_reverse(pairs);
      } else if (first) {
        single_uid = g_strdup(value_get_string(first));
        if (fl_value_get_length(args) > 1)
          single_vcard =
              g_strdup(value_get_string(fl_value_index(args, 1)));
      }
    }
    struct UpdJob {
      FlContactsPlugin* plugin;
      FlMethodCall* call;
      GList* pairs;
      gchar* uid;
      gchar* vcard;
      gboolean batch;
    };
    UpdJob* job = g_new0(UpdJob, 1);
    job->plugin = (FlContactsPlugin*)g_object_ref(self);
    job->call = (FlMethodCall*)g_object_ref(method_call);
    job->pairs = pairs;
    job->uid = single_uid;
    job->vcard = single_vcard;
    job->batch = strcmp(method, "updateAll") == 0;
    g_thread_new(
        "fl-mutate", [](gpointer data) -> gpointer {
          UpdJob* job = (UpdJob*)data;
          if (job->batch) {
            // Split combined uid\nvcard entries for ModifyContacts.
            GList* vcards = NULL;
            for (GList* l = job->pairs; l; l = l->next) {
              gchar* nl = strchr((gchar*)l->data, '\n');
              if (nl) vcards = g_list_prepend(vcards, g_strdup(nl + 1));
            }
            vcards = g_list_reverse(vcards);
            worker_update(job->plugin, job->call, NULL, NULL, TRUE, vcards);
            g_list_free_full(vcards, g_free);
          } else {
            worker_update(job->plugin, job->call, job->uid, job->vcard,
                          FALSE, NULL);
          }
          g_list_free_full(job->pairs, g_free);
          g_free(job->uid);
          g_free(job->vcard);
          g_clear_object(&job->call);
          g_object_unref(job->plugin);
          g_free(job);
          return NULL;
        },
        job);
    return;
  }
  if (strcmp(method, "delete") == 0) {
    GList* uids = NULL;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_LIST) {
      size_t n = fl_value_get_length(args);
      for (size_t i = 0; i < n; i++) {
        const gchar* s = value_get_string(fl_value_index(args, i));
        if (s) uids = g_list_prepend(uids, g_strdup(s));
      }
      uids = g_list_reverse(uids);
    }
    struct DelJob {
      FlContactsPlugin* plugin;
      FlMethodCall* call;
      GList* uids;
    };
    DelJob* job = g_new0(DelJob, 1);
    job->plugin = (FlContactsPlugin*)g_object_ref(self);
    job->call = (FlMethodCall*)g_object_ref(method_call);
    job->uids = uids;
    g_thread_new(
        "fl-mutate", [](gpointer data) -> gpointer {
          DelJob* job = (DelJob*)data;
          worker_delete(job->plugin, job->call, job->uids);
          g_list_free_full(job->uids, g_free);
          g_clear_object(&job->call);
          g_object_unref(job->plugin);
          g_free(job);
          return NULL;
        },
        job);
    return;
  }
  // Everything else is not implemented on Linux.
  if (strcmp(method, "getGroups") == 0) {
    g_object_ref(method_call);
    FlContactsPlugin* plugin = (FlContactsPlugin*)g_object_ref(self);
    struct GroupJob {
      FlContactsPlugin* plugin;
      FlMethodCall* call;
    };
    GroupJob* job = g_new0(GroupJob, 1);
    job->plugin = plugin;
    job->call = method_call;
    g_thread_new(
        "fl-groups", [](gpointer data) -> gpointer {
          GroupJob* job = (GroupJob*)data;
          worker_get_groups(job->plugin, job->call);
          g_clear_object(&job->call);
          g_object_unref(job->plugin);
          g_free(job);
          return NULL;
        },
        job);
    return;
  }
  if (strcmp(method, "getGroupsOf") == 0) {
    const gchar* uid = NULL;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_LIST &&
        fl_value_get_length(args) > 0) {
      uid = value_get_string(fl_value_index(args, 0));
    }
    g_object_ref(method_call);
    FlContactsPlugin* plugin = (FlContactsPlugin*)g_object_ref(self);
    struct GroupsOfJob {
      FlContactsPlugin* plugin;
      FlMethodCall* call;
      gchar* uid;
    };
    GroupsOfJob* job = g_new0(GroupsOfJob, 1);
    job->plugin = plugin;
    job->call = method_call;
    job->uid = g_strdup(uid ? uid : "");
    g_thread_new(
        "fl-groups", [](gpointer data) -> gpointer {
          GroupsOfJob* job = (GroupsOfJob*)data;
          worker_groups_of(job->plugin, job->call, job->uid);
          g_free(job->uid);
          g_clear_object(&job->call);
          g_object_unref(job->plugin);
          g_free(job);
          return NULL;
        },
        job);
    return;
  }
  if (strcmp(method, "addContactsToGroup") == 0 ||
      strcmp(method, "removeContactsFromGroup") == 0) {
    const gchar* group = NULL;
    GList* uids = NULL;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_LIST &&
        fl_value_get_length(args) > 1) {
      group = value_get_string(fl_value_index(args, 0));
      FlValue* ids = fl_value_index(args, 1);
      if (ids && fl_value_get_type(ids) == FL_VALUE_TYPE_LIST) {
        size_t n = fl_value_get_length(ids);
        for (size_t i = 0; i < n; i++) {
          const gchar* s = value_get_string(fl_value_index(ids, i));
          if (s) uids = g_list_prepend(uids, g_strdup(s));
        }
        uids = g_list_reverse(uids);
      }
    }
    gboolean add = strcmp(method, "addContactsToGroup") == 0;
    g_object_ref(method_call);
    FlContactsPlugin* plugin = (FlContactsPlugin*)g_object_ref(self);
    struct MembershipJob {
      FlContactsPlugin* plugin;
      FlMethodCall* call;
      gchar* group;
      GList* uids;
      gboolean add;
    };
    MembershipJob* job = g_new0(MembershipJob, 1);
    job->plugin = plugin;
    job->call = method_call;
    job->group = g_strdup(group ? group : "");
    job->uids = uids;
    job->add = add;
    g_thread_new(
        "fl-groups", [](gpointer data) -> gpointer {
          MembershipJob* job = (MembershipJob*)data;
          worker_set_membership(job->plugin, job->call, job->group, job->uids,
                                job->add);
          g_free(job->group);
          g_list_free_full(job->uids, g_free);
          g_clear_object(&job->call);
          g_object_unref(job->plugin);
          g_free(job);
          return NULL;
        },
        job);
    return;
  }
  g_object_ref(method_call);
  CallResult* cr = g_new0(CallResult, 1);
  cr->call = method_call;
  cr->response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  g_main_context_invoke(NULL, respond_in_main, cr);
}

FlMethodResponse* get_platform_version() {
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "platform", fl_value_new_string("linux"));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void view_drop_local(FlContactsPlugin* self) {
  // Local-only teardown for dispose (main thread): no round trips.
  g_autoptr(GDBusConnection) connection =
      g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, NULL);
  if (connection) {
    if (self->view_sub_added)
      g_dbus_connection_signal_unsubscribe(connection, self->view_sub_added);
    if (self->view_sub_modified)
      g_dbus_connection_signal_unsubscribe(connection, self->view_sub_modified);
    if (self->view_sub_removed)
      g_dbus_connection_signal_unsubscribe(connection, self->view_sub_removed);
  }
  self->view_sub_added = self->view_sub_modified = self->view_sub_removed = 0;
  g_clear_pointer(&self->view_path, g_free);
  g_clear_pointer(&self->view_bus_name, g_free);
}

static void fl_contacts_plugin_dispose(GObject* object) {
  FlContactsPlugin* self = FL_CONTACTS(object);
  view_drop_local(self);
  g_clear_pointer(&self->book_bus_name, g_free);
  g_clear_pointer(&self->book_object_path, g_free);
  g_clear_pointer(&self->view_path, g_free);
  g_clear_pointer(&self->view_bus_name, g_free);
  g_clear_object(&self->legacy_sink);
  g_clear_object(&self->changes_sink);
  g_mutex_clear(&self->session_lock);
  g_mutex_clear(&self->sink_lock);
  G_OBJECT_CLASS(fl_contacts_plugin_parent_class)->dispose(object);
}

static void fl_contacts_plugin_class_init(FlContactsPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fl_contacts_plugin_dispose;
}

static void fl_contacts_plugin_init(FlContactsPlugin* self) {
  g_mutex_init(&self->session_lock);
  g_mutex_init(&self->sink_lock);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlContactsPlugin* plugin = FL_CONTACTS(user_data);
  (void)channel;
  fl_contacts_plugin_handle_method_call(plugin, method_call);
}

void fl_contacts_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlContactsPlugin* plugin = FL_CONTACTS(
      g_object_new(fl_contacts_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), FL_CHANNEL,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);
  g_autoptr(FlEventChannel) legacy = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar), FL_EVENTS_CHANNEL,
      FL_METHOD_CODEC(codec));
  g_autoptr(FlEventChannel) changes = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar), FL_CHANGES_CHANNEL,
      FL_METHOD_CODEC(codec));
  FlStreamHandler* legacy_handler =
      (FlStreamHandler*)g_object_new(fl_stream_handler_get_type(), NULL);
  legacy_handler->plugin = plugin;
  legacy_handler->detailed = FALSE;
  fl_event_channel_set_stream_handler(
      legacy, FL_EVENT_STREAM_HANDLER(legacy_handler), NULL, NULL);
  FlStreamHandler* changes_handler =
      (FlStreamHandler*)g_object_new(fl_stream_handler_get_type(), NULL);
  changes_handler->plugin = plugin;
  changes_handler->detailed = TRUE;
  fl_event_channel_set_stream_handler(
      changes, FL_EVENT_STREAM_HANDLER(changes_handler), NULL, NULL);

  g_object_unref(plugin);
}
