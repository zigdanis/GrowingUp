require 'tmpdir'
require 'fileutils'
require 'fastlane'
require 'cfpropertylist'

Fastlane.load_actions
fastfile = Fastlane::FastFile.new(File.expand_path('../Fastfile', __dir__))

Dir.mktmpdir('growingup-archive-test-') do |archive|
  app = File.join(archive, 'Products/Applications/GrowingUp.app')
  widget = File.join(app, 'PlugIns/Widget.appex')
  FileUtils.mkdir_p(widget)
  record = { 'version' => '2.1.4', 'build_number' => '26' }
  [app, widget].zip([TestflightRelease::APP_ID, TestflightRelease::WIDGET_ID]).each do |directory, identifier|
    plist = CFPropertyList::List.new
    plist.value = CFPropertyList.guess('CFBundleIdentifier' => identifier,
                                     'CFBundleShortVersionString' => record['version'],
                                     'CFBundleVersion' => record['build_number'],
                                     'CFBundleDisplayName' => 'GrowingUp 🌱',
                                     'DTPlatformName' => 'iphoneos', 'DTPlatformVersion' => '27.1')
    plist.save(File.join(directory, 'Info.plist'), CFPropertyList::List::FORMAT_BINARY)
  end

  fastfile.verify_release_archive(archive, record)

  plist = CFPropertyList::List.new(file: File.join(widget, 'Info.plist'))
  data = CFPropertyList.native_types(plist.value).merge('CFBundleVersion' => '27')
  plist.value = CFPropertyList.guess(data)
  plist.save(File.join(widget, 'Info.plist'), CFPropertyList::List::FORMAT_BINARY)
  begin
    fastfile.verify_release_archive(archive, record)
    raise 'Archive verification accepted a widget with the wrong build number'
  rescue FastlaneCore::Interface::FastlaneError => error
    raise unless error.message.include?('version or build number differs')
  end

  [app, widget].each do |directory|
    plist = CFPropertyList::List.new(file: File.join(directory, 'Info.plist'))
    data = CFPropertyList.native_types(plist.value).merge('CFBundleVersion' => '26', 'DTPlatformVersion' => '26.5')
    plist.value = CFPropertyList.guess(data)
    plist.save(File.join(directory, 'Info.plist'), CFPropertyList::List::FORMAT_BINARY)
  end
  begin
    fastfile.verify_release_archive(archive, record)
    raise 'Archive verification accepted an app built with an SDK that letterboxes on iPhone Duo'
  rescue FastlaneCore::Interface::FastlaneError => error
    raise unless error.message.include?('iOS 27.1 SDK or later')
  end
end
puts 'Binary archive verification checks passed.'
