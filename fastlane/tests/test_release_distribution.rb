require 'pilot'
require 'fastlane'
require_relative '../testflight_release'

Fastlane.load_actions
fastfile = Fastlane::FastFile.new(File.expand_path('../Fastfile', __dir__))
fastfile.validate_release_notes('en-US' => "What's New\n• Photo saving fixed.", 'ru' => 'Что нового: сохранение фото исправлено.')
['New photo controls 🌱', 'Test children < 3'].each do |text|
  begin
    fastfile.validate_release_notes('en-US' => text)
    raise 'Notes accepted text that pinned Pilot silently changes'
  rescue FastlaneCore::Interface::FastlaneError => error
    raise unless error.message.include?('Fastlane would alter them')
  end
end

release = TestflightRelease.new('GITHUB_REPOSITORY' => 'example/GrowingUp', 'GITHUB_RUN_ID' => '100')
release.instance_variable_set(:@app, { 'id' => 'app' })
release.instance_variable_set(:@group, { 'id' => 'group', 'attributes' => { 'isInternalGroup' => false } })
release.record.merge!('version' => '2.1.4', 'build_number' => '26', 'notes' => {})

options = FastlaneCore::Configuration.create(Pilot::Options.available_options, release.pilot_options)
manager = Pilot::Manager.new
manager.instance_variable_set(:@config, options)
raise 'Distribution must resolve iOS without an IPA or interactive input' unless manager.fetch_app_platform == 'ios'

puts 'Noninteractive distribution platform check passed.'
