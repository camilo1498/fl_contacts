Pod::Spec.new do |s|
  s.name             = 'fl_contacts'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin to read, create, update, delete and observe native contacts.'
  s.description      = <<-DESC
Flutter plugin to read, create, update, delete and observe native contacts on Android and iOS, with group support, vCard support, and contact permission handling.
                       DESC
  s.homepage         = 'https://github.com/QuisApp/fl_contacts'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'QuisApp' => 'https://github.com/QuisApp' }
  s.source           = { :path => '.' }
  # Shared with Swift Package Manager: same Sources layout, same privacy file.
  s.source_files = 'fl_contacts/Sources/fl_contacts/**/*.swift'
  s.resource_bundles = {'fl_contacts_privacy' => ['fl_contacts/Sources/fl_contacts/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.platform = :osx, '10.15'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=macosx*]' => 'i386' }
  s.swift_version = '5.0'
end
