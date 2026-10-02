#ifndef FLUTTER_PLUGIN_FL_CONTACTS_PLUGIN_H_
#define FLUTTER_PLUGIN_FL_CONTACTS_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace fl_contacts {

// System contacts on Windows via Windows.ApplicationModel.Contacts (WinRT).
//
// Reads and writes go through the app contact store; change events come from
// the store change tracker polled while listeners are attached, plus
// immediate events for mutations performed through this plugin. All WinRT
// work runs off the platform thread; results hop back through the messenger.
class FlContactsPlugin : public flutter::Plugin,
                         public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlContactsPlugin();

  virtual ~FlContactsPlugin();

  // Disallow copy and assign.
  FlContactsPlugin(const FlContactsPlugin &) = delete;
  FlContactsPlugin &operator=(const FlContactsPlugin &) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 protected:
  // StreamHandler implementation for contactChanges.
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue *arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events) override;
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue *arguments) override;

 private:
  // Starts/stops the change-tracker poll while event listeners exist.
  void EnsurePolling();
  void StopPolling();

  flutter::PluginRegistrarWindows *registrar_ = nullptr;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::mutex sink_mutex_;
  std::thread poll_thread_;
  std::atomic<bool> polling_{false};
};

}  // namespace fl_contacts

#endif  // FLUTTER_PLUGIN_FL_CONTACTS_PLUGIN_H_
