require 'tmpdir'
require 'fastlane'
require 'xcodeproj'

Fastlane.load_actions
fastfile = Fastlane::FastFile.new(File.expand_path('../Fastfile', __dir__))
context = {}
fastfile.define_singleton_method(:lane_context) { context }
fastfile.define_singleton_method(:app_store_connect_api_key) { |**| { token: 'test-only' } }
fastfile.define_singleton_method(:pilot) { |**| raise 'Archive/plan must never call Pilot' }

fake_class = Class.new do
  attr_reader :record, :events
  def initialize
    @events = []
    @record = { 'version' => '2.1.0', 'build_number' => '37', 'release_id' => '123',
                'notes' => { 'en-US' => 'Check photos.', 'ru' => 'Проверьте фото.' } }
  end
  def requested_notes = record['notes']
  def preflight!(configure:) = events << [:preflight, configure]
  def plan! = events << :plan
  def prepare! = events << :reserve
  def reusable_ipa = nil
  def upload_needed? = true
  def archived!(archive, ipa)
    raise 'IPA was not exported' unless File.file?(ipa)
    record['phase'] = 'archived'
    events << :archived
  end
  def write_report = nil
end
original_new = TestflightRelease.method(:new)
original_env = ENV.to_h
begin
  Dir.mktmpdir('growingup-release-execution-') do |directory|
    ENV.update('RELEASE_EXECUTOR' => 'local', 'RELEASE_SOURCE_DIR' => File.expand_path('../..', __dir__),
               'RELEASE_TEMP' => directory, 'ASC_KEY_ID' => 'test', 'ASC_ISSUER_ID' => 'test',
               'ASC_KEY_PATH' => File.join(directory, 'test.p8'), 'APPLE_TEAM_ID' => 'test')
    ENV.delete('GITHUB_ACTIONS')
    ENV.delete('RESUME_RUN_ID')
    fake = fake_class.new
    TestflightRelease.define_singleton_method(:new) { fake }
    fastfile.define_singleton_method(:with_release_signing) do |_, local:, readonly:, &block|
      raise 'Local signing must use readonly Match' unless local && readonly
      context[Fastlane::Actions::SharedValues::MATCH_PROVISIONING_PROFILE_MAPPING] = {}
      block.call
    end
    fastfile.define_singleton_method(:configure_release_signing) { |*| nil }
    fastfile.define_singleton_method(:gym) { |**options| File.write(File.join(options.fetch(:output_directory), 'GrowingUp.ipa'), 'test-ipa') }
    fastfile.define_singleton_method(:verify_release_archive) { |*| fake.events << :archive_verified }
    fastfile.define_singleton_method(:verify_release_signature) { |*| fake.events << :signature_verified }
    fastfile.define_singleton_method(:verify_release_ipa) { |*| fake.events << :ipa_verified }
    fastfile.run_release(upload: false, archive_only: true)
    expected = [[:preflight, false], :reserve, :archive_verified, :signature_verified, :ipa_verified, :archived]
    raise "Unexpected archive events: #{fake.events.inspect}" unless fake.events == expected

    fake = fake_class.new
    TestflightRelease.define_singleton_method(:new) { fake }
    fastfile.run_release(upload: false)
    raise 'Plan must not reserve or build' unless fake.events == [[:preflight, false], :plan]

    ENV['RELEASE_EXECUTOR'] = 'unsupported'
    begin
      fastfile.run_release(upload: false)
      raise 'Unsupported local executor accepted'
    rescue FastlaneCore::Interface::FastlaneError => error
      raise unless error.message.include?('explicit local or cloud executor')
    end
  end
ensure
  TestflightRelease.define_singleton_method(:new, original_new)
  ENV.replace(original_env)
end
puts 'Local executor, readonly plan and no-upload archive checks passed.'
