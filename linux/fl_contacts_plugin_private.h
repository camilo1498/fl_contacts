#include "include/fl_contacts/fl_contacts_plugin.h"

#include "fl_contacts_plugin_private.h"

// This file exposes some plugin internals for unit testing.
G_BEGIN_DECLS

// Handles the getPlatformVersion method call.
FlMethodResponse *get_platform_version();

G_END_DECLS
