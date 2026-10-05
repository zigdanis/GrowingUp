require 'pilot'
require_relative '../testflight_release'

release = TestflightRelease.new('GITHUB_REPOSITORY' => 'example/GrowingUp', 'GITHUB_RUN_ID' => '100')
release.instance_variable_set(:@app, { 'id' => 'app' })
release.instance_variable_set(:@group, { 'id' => 'group', 'attributes' => { 'isInternalGroup' => false } })
release.record.merge!('version' => '2.1.4', 'build_number' => '26', 'notes' => {})

options = FastlaneCore::Configuration.create(Pilot::Options.available_options, release.pilot_options)
manager = Pilot::Manager.new
manager.instance_variable_set(:@config, options)
raise 'Distribution must resolve iOS without an IPA or interactive input' unless manager.fetch_app_platform == 'ios'

puts 'Noninteractive distribution platform check passed.'
