gem 'minitest', '~> 5.0'
require 'minitest/mock'
require 'minitest/autorun'
require 'tmpdir'
require_relative '../testflight_release'

class TestflightReleaseTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir('growingup-release-test-')
    @env = { 'GITHUB_REPOSITORY' => 'example/GrowingUp', 'GITHUB_RUN_ID' => '100',
             'SOURCE_SHA' => 'a' * 40, 'RELEASE_RECEIPT' => File.join(@directory, 'release.json'),
             'PROJECT_VERSION' => '2.1.3', 'PROJECT_BUILD' => '24', 'MARKETING_VERSION' => 'next',
             'NOTES_EN' => 'Check photos and widgets.', 'NOTES_RU' => 'Проверьте фотографии и виджет.' }
    @release = TestflightRelease.new(@env)
    @release.instance_variable_set(:@app, { 'id' => 'app' })
    @release.instance_variable_set(:@group, { 'id' => 'group' })
    @release.instance_variable_set(:@tester_id, 'danis')
    @release.instance_variable_set(:@versions, %w[2.1.3 2.1.10])
    @release.instance_variable_set(:@builds, [{ 'attributes' => { 'version' => '27' } }])
    @release.instance_variable_set(:@uploads, [{ 'attributes' => { 'cfBundleVersion' => '29' } }])
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def reserve(previous = [])
    @release.stub(:records, previous) do
      @release.stub(:save!, -> { @saved = @release.record.dup }) do
        @release.stub(:with_allocation_lock, ->(&block) { block.call }) { @release.prepare! }
      end
    end
  end

  def atomic_action
    @release.stub(:with_allocation_lock, ->(&block) { block.call }) do
      @release.stub(:records, -> { [@release.record.dup] }) do
        @release.stub(:exact_build, nil) { yield }
      end
    end
  end

  def prior_record(phase: 'uploading', source: 'a' * 40)
    { 'release_id' => '100', 'source_sha' => source, 'version' => '2.1.11', 'build_number' => '31',
      'app_id' => 'app', 'group_id' => 'group', 'tester_id' => 'danis', 'phase' => phase,
      'notes' => { 'en-US' => 'Original notes', 'ru' => 'Исходные заметки' } }
  end

  def test_allocates_above_processed_uploading_and_reserved_versions_and_builds
    reserve([prior_record.merge('release_id' => '90', 'source_sha' => 'b' * 40, 'build_number' => '35')])
    assert_equal '36', @saved['build_number']
    assert_equal '2.1.12', @saved['version']
    assert_equal 'reserved', @saved['phase']
  end

  def test_numeric_version_order_and_dotted_historical_builds
    assert_equal '2.1.11', TestflightRelease.next_version(%w[2.1.9 2.1.10])
    assert_equal '3.0.1', TestflightRelease.next_version(%w[2.9.99 3.0])
    assert_equal 31, TestflightRelease.next_build(%w[24 30.4.2 29])
  end

  def test_retry_preserves_build_version_and_notes
    reserve([prior_record])
    assert_equal '31', @release.record['build_number']
    assert_equal '2.1.11', @release.record['version']
    assert_equal 'Original notes', @release.record.dig('notes', 'en-US')
    assert_nil @saved
  end

  def test_notes_verification_reads_both_apple_locales_and_rejects_missing_or_stale_text
    reserve([prior_record])
    build = { 'id' => 'apple-build' }
    localizations = @release.record['notes'].map do |locale, text|
      { 'attributes' => { 'locale' => locale, 'whatsNew' => text } }
    end
    @release.stub(:asc, ->(path) { assert_equal '/v1/builds/apple-build/betaBuildLocalizations', path; [localizations, []] }) do
      @release.stub(:save!, nil) do
        @release.verify_notes!(build)
        assert_equal 'verified', @release.record['notes_status']
        localizations.last['attributes']['whatsNew'] = 'Stale instructions'
        assert_raises(RuntimeError) { @release.verify_notes!(build) }
        assert_equal 'mismatch', @release.record['notes_status']
        localizations.clear
        assert_raises(RuntimeError) { @release.verify_notes!(build) }
        assert_equal({}, @release.record['apple_notes'])
      end
    end
  end

  def test_notes_update_reuses_build_and_updates_or_creates_locales_before_readback
    @env['RESUME_RUN_ID'] = '100'
    reserve([prior_record(phase: 'available')])
    identity = @release.record.values_at('release_id', 'source_sha', 'version', 'build_number', 'phase')
    localizations = [{ 'id' => 'english', 'attributes' => { 'locale' => 'en-US', 'whatsNew' => 'Old notes' } }]
    calls = []
    api = Module.new
    api.define_singleton_method(:patch_beta_build_localizations) do |**args|
      calls << [:patch, args]
      localizations.first['attributes']['whatsNew'] = args[:attributes][:whatsNew]
    end
    api.define_singleton_method(:post_beta_build_localizations) do |**args|
      calls << [:post, args]
      localizations << { 'attributes' => { 'locale' => args[:attributes][:locale], 'whatsNew' => args[:attributes][:whatsNew] } }
    end
    namespace = Module.new
    namespace.const_set(:ConnectAPI, api)
    Object.const_set(:Spaceship, namespace)
    build = { 'id' => 'apple-build', 'attributes' => { 'processingState' => 'VALID' } }
    @release.stub(:exact_build, build) do
      @release.stub(:asc, ->(*) { [localizations, []] }) do
        @release.stub(:save!, nil) { @release.update_notes! }
      end
    end
    assert_equal identity, @release.record.values_at('release_id', 'source_sha', 'version', 'build_number', 'phase')
    assert_equal [:patch, :post], calls.map(&:first)
    assert_equal 'english', calls.first.last[:localization_id]
    assert_equal 'apple-build', calls.last.last[:build_id]
    assert_equal @env['NOTES_RU'], @release.record.dig('apple_notes', 'ru')
    assert_equal 'verified', @release.record['notes_status']
  ensure
    Object.send(:remove_const, :Spaceship) if Object.const_defined?(:Spaceship)
  end

  def test_notes_update_refuses_unrecorded_or_unprocessed_builds
    reserve
    assert_raises(RuntimeError) { @release.update_notes! }
    @env['RESUME_RUN_ID'] = '100'
    [nil, { 'attributes' => { 'processingState' => 'PROCESSING' } }].each do |build|
      @release.stub(:exact_build, build) { assert_raises(RuntimeError) { @release.update_notes! } }
    end
    @env['NOTES_RU'] = ' '
    @release.stub(:exact_build, { 'attributes' => { 'processingState' => 'VALID' } }) do
      assert_raises(RuntimeError) { @release.update_notes! }
    end
  end

  def test_retry_refuses_different_source_or_recipient
    assert_raises(RuntimeError) { reserve([prior_record(source: 'b' * 40)]) }
    assert_raises(RuntimeError) { reserve([prior_record.merge('tester_id' => 'someone-else')]) }
  end

  def test_upload_intent_prevents_duplicate_after_runner_failure
    reserve
    @release.stub(:save!, nil) { atomic_action { @release.begin_upload! } }
    @release.stub(:exact_build, nil) { refute @release.upload_needed? }
    atomic_action { refute @release.begin_upload! }
  end

  def test_reserved_release_can_upload_but_visible_build_is_reused
    reserve
    @release.stub(:exact_build, nil) { assert @release.upload_needed? }
    @release.stub(:exact_build, { 'id' => 'apple-build' }) { refute @release.upload_needed? }
  end

  def test_new_dispatch_cannot_duplicate_pending_source
    pending = prior_record.merge('release_id' => '90')
    assert_raises(RuntimeError) { reserve([pending]) }
    assert_nil @saved
  end

  def test_explicit_marketing_version_can_reuse_lower_beta_train_above_approved_store_floor
    @release.instance_variable_set(:@store_floor_versions, ['2.0.0'])
    @env['MARKETING_VERSION'] = '2.1.0'
    reserve([prior_record.merge('release_id' => '90', 'source_sha' => 'b' * 40)])
    assert_equal '2.1.0', @saved['version']
    assert_equal '32', @saved['build_number']
    @env['MARKETING_VERSION'] = '2.0.0'
    assert_raises(RuntimeError) { reserve }
    @env['MARKETING_VERSION'] = '1.9.9'
    assert_raises(RuntimeError) { reserve }
  end

  def test_missing_resume_receipt_never_reserves_another_build
    @env['RESUME_RUN_ID'] = '90'
    @release = TestflightRelease.new(@env)
    assert_raises(RuntimeError) { reserve }
    assert_nil @saved
  end

  def test_receipt_creation_and_updates_are_single_private_mutations
    reserve
    calls = []
    @release.stub(:github, ->(path, **options) { calls << [path, options]; { 'id' => 42 } }) do
      @release.save!
      atomic_action { @release.begin_upload! }
    end
    assert_equal ['releases', 'releases/42'], calls.map(&:first)
    assert_equal %w[POST PATCH], calls.map { |call| call.last[:method] }
    assert calls.all? { |call| call.last[:data][:draft] }
    assert_equal 'uploading', JSON.parse(calls.last.last[:data][:body])['phase']
  end

  def test_retry_recovers_receipt_after_lost_creation_response
    stored = { 'id' => 42, 'draft' => true, 'tag_name' => 'testflight/receipts/100', 'body' => JSON.generate(prior_record) }
    @release.stub(:github, [[stored]]) do
      @release.stub(:with_allocation_lock, ->(&block) { block.call }) { @release.prepare! }
    end
    assert_equal 42, @release.record['receipt_id']
    @release.stub(:exact_build, nil) { refute @release.upload_needed? }
  end

  def test_ungrouped_app_tester_is_assigned_without_reporting_the_roster
    assigned = []
    api = Module.new
    api.define_singleton_method(:add_beta_tester_to_group) { |**args| assigned << args }
    namespace = Module.new
    namespace.const_set(:ConnectAPI, api)
    Object.const_set(:Spaceship, namespace)
    tester = { 'id' => 'danis', 'attributes' => { 'firstName' => 'Danis', 'email' => 'private-danis@example.test' } }
    another = { 'id' => 'private-alex-id', 'attributes' => { 'firstName' => 'Private Alex', 'email' => 'private-alex@example.test' } }
    group = { 'id' => 'group', 'attributes' => { 'name' => 'Internal', 'isInternalGroup' => true } }
    responses = { '/v1/apps' => [{ 'id' => 'app' }], '/v1/apps/app/betaGroups' => [group],
                  '/v1/betaTesters' => [tester, another], '/v1/betaGroups/group/betaTesters' => [] }
    @release.stub(:asc, ->(path, _params = {}) { [responses.fetch(path, []), []] }) { @release.preflight! }
    assert_equal [{ beta_group_id: 'group', beta_tester_ids: ['danis'] }], assigned
    report = File.read(@env['RELEASE_RECEIPT'])
    refute_includes report, 'Private Alex'
    refute_includes report, 'private-alex-id'
    refute_includes report, 'private-alex@example.test'
    refute_includes report, 'private-danis@example.test'
  ensure
    Object.send(:remove_const, :Spaceship) if Object.const_defined?(:Spaceship)
  end

  def test_absent_optional_review_secret_and_invalid_json_are_safe
    @env['BETA_REVIEW_INFO'] = ''
    assert_equal({}, @release.review_info)
    @env['BETA_REVIEW_INFO'] = 'sensitive-invalid-value'
    error = assert_raises(RuntimeError) { @release.review_info }
    refute_includes error.message, 'sensitive-invalid-value'
    assert_nil error.cause
  end

  def test_non_json_apple_failure_preserves_status_and_path_without_body
    token = Struct.new(:text) do
      def expired? = false
    end.new('test-token')
    api = Module.new
    api.define_singleton_method(:token) { token }
    namespace = Module.new
    namespace.const_set(:ConnectAPI, api)
    Object.const_set(:Spaceship, namespace)
    response = Net::HTTPBadGateway.new('1.1', '502', 'Bad Gateway')
    response.define_singleton_method(:body) { '<html>upstream error details</html>' }
    Net::HTTP.stub(:start, ->(*) { response }) do
      error = assert_raises(RuntimeError) { @release.asc('/v1/apps') }
      assert_includes error.message, 'Apple API /v1/apps returned HTTP 502'
      refute_includes error.message, 'upstream error details'
    end
  ensure
    Object.send(:remove_const, :Spaceship) if Object.const_defined?(:Spaceship)
  end
  def test_plan_is_read_only_and_includes_reserved_builds_without_needing_notes
    @env.delete('NOTES_EN')
    @env.delete('NOTES_RU')
    @release.instance_variable_set(:@inventory, {})
    previous = [prior_record.merge('release_id' => '90', 'source_sha' => 'b' * 40)]
    @release.stub(:records, previous) do
      @release.stub(:save!, -> { flunk 'Plan must not create a receipt' }) { @release.plan! }
    end
    assert_equal '2.1.12', @release.inventory['next_version']
    assert_equal '32', @release.inventory['next_build']
    assert_equal 'planned', @release.record['phase']
  end

  def test_archived_release_keeps_identity_and_reuses_only_unchanged_ipa
    reserve
    ipa = File.join(@directory, 'GrowingUp.ipa')
    File.write(ipa, 'verified-artifact')
    @release.stub(:save!, nil) { atomic_action { @release.archived!(@directory, ipa) } }
    assert_equal ipa, @release.reusable_ipa
    @release.stub(:exact_build, nil) { assert @release.upload_needed? }
    File.write(ipa, 'changed-artifact')
    assert_raises(RuntimeError) { @release.reusable_ipa }
    @release.stub(:save!, nil) { atomic_action { @release.begin_upload! } }
    assert_nil @release.reusable_ipa
  end

  def test_atomic_allocation_ref_guards_all_receipt_reads_and_is_released
    acquired = false
    events = []
    api = lambda do |path, method: 'GET', data: nil|
      events << [path, method]
      case [path, method]
      when ['git/tags', 'POST'] then { 'sha' => 'unique-owner-tag' }
      when ['git/refs', 'POST']
        assert_equal 'refs/tags/testflight/allocation-lock', data[:ref]
        acquired = true
        {}
      when ['git/ref/tags/testflight/allocation-lock', 'GET'] then { 'object' => { 'sha' => 'unique-owner-tag' } }
      when ['git/refs/tags/testflight/allocation-lock', 'DELETE'] then acquired = false; nil
      else flunk "Unexpected lock API operation #{path} #{method}"
      end
    end
    @release.stub(:github, api) do
      @release.stub(:records, -> { assert acquired; [] }) do
        @release.stub(:save!, -> { assert acquired }) { @release.prepare! }
      end
    end
    refute acquired
    assert_equal ['git/refs/tags/testflight/allocation-lock', 'DELETE'], events.last
  end

  def test_contention_never_reads_receipts_or_steals_existing_lock
    calls = []
    api = lambda do |path, method: 'GET', data: nil|
      calls << [path, method]
      case [path, method]
      when ['git/tags', 'POST'] then { 'sha' => 'our-lock' }
      when ['git/refs', 'POST'] then raise TestflightRelease::GithubError.new('held', 422)
      when ['git/ref/tags/testflight/allocation-lock', 'GET'] then { 'object' => { 'sha' => 'other-lock' } }
      else flunk 'Contending release must not mutate or delete the existing lock'
      end
    end
    times = [0, 46]
    @release.stub(:github, api) do
      Process.stub(:clock_gettime, ->(*) { times.shift || 46 }) do
        @release.stub(:records, -> { flunk 'Receipt allocation cannot run without the lock' }) do
          error = assert_raises(RuntimeError) { @release.prepare! }
          assert_includes error.message, 'release process has stopped'
        end
      end
    end
    refute calls.any? { |_, method| method == 'DELETE' }
  end

  def test_lock_released_when_numbering_fails
    deleted = false
    @release.stub(:github, lambda { |path, method: 'GET', data: nil|
      deleted = true if method == 'DELETE'
      path == 'git/tags' ? { 'sha' => 'lock' } : { 'object' => { 'sha' => 'lock' } }
    }) do
      assert_raises(RuntimeError) { @release.with_allocation_lock { raise 'numbering failed' } }
    end
    assert deleted
  end

  def test_plan_does_not_block_pending_release_on_same_source
    @release.instance_variable_set(:@inventory, {})
    @release.stub(:records, [prior_record.merge('release_id' => '90')]) { @release.plan! }
    assert_equal 'planned', @release.record['phase']
    assert_equal '32', @release.record['build_number']
  end

  def test_explicit_different_train_allowed_only_after_prior_upload_is_valid
    @env['MARKETING_VERSION'] = '2.1.0'
    pending = prior_record(phase: 'awaiting_apple_review').merge('release_id' => '90', 'processing_status' => 'VALID')
    reserve([pending])
    assert_equal '2.1.0', @saved['version']
    assert_equal '32', @saved['build_number']
    pending['processing_status'] = 'PROCESSING'
    assert_raises(RuntimeError) { reserve([pending]) }
    pending['processing_status'] = 'VALID'
    pending['version'] = '2.1.0'
    assert_raises(RuntimeError) { reserve([pending]) }
    pending['version'] = '2.1.11'
    @env['MARKETING_VERSION'] = 'next'
    assert_raises(RuntimeError) { reserve([pending]) }
  end

  def test_concurrent_resumes_only_one_runner_can_claim_upload
    reserve
    ipa = File.join(@directory, 'GrowingUp.ipa')
    File.write(ipa, 'verified-ipa')
    @release.record.merge!('phase' => 'archived', 'artifacts' => { 'ipa' => ipa, 'ipa_sha256' => Digest::SHA256.file(ipa).hexdigest })
    stored = Marshal.load(Marshal.dump(@release.record))
    mutex = Mutex.new
    clones = [@release, @release.dup]
    clones.last.instance_variable_set(:@record, Marshal.load(Marshal.dump(@release.record)))
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = clones.map do |release|
      Thread.new do
        release.stub(:with_allocation_lock, ->(&block) { mutex.synchronize { block.call } }) do
          release.stub(:records, -> { [Marshal.load(Marshal.dump(stored))] }) do
            release.stub(:save!, -> { stored = Marshal.load(Marshal.dump(release.record)) }) do
              release.stub(:exact_build, nil) do
                ready << true
                start.pop
                results << release.begin_upload!(ipa: ipa)
              end
            end
          end
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:value)
    assert_equal [false, true], 2.times.map { results.pop }.sort_by(&:to_s)
    assert_equal 'uploading', stored['phase']
  end

  def test_late_archive_cannot_undo_another_runners_upload_claim
    reserve
    ipa = File.join(@directory, 'GrowingUp.ipa')
    File.write(ipa, 'late-ipa')
    stored = @release.record.merge('phase' => 'uploading')
    @release.stub(:with_allocation_lock, ->(&block) { block.call }) do
      @release.stub(:records, [stored]) do
        @release.stub(:save!, -> { flunk 'Late archive must not overwrite upload intent' }) do
          refute @release.archived!(@directory, ipa)
        end
      end
    end
    assert_equal 'uploading', @release.record['phase']
  end

  def test_upload_claim_rejects_ipa_replaced_by_another_executor
    reserve
    ipa = File.join(@directory, 'GrowingUp.ipa')
    File.write(ipa, 'different-ipa')
    @release.record.merge!('phase' => 'archived', 'artifacts' => { 'ipa_sha256' => 'other-artifact-hash' })
    atomic_action do
      @release.stub(:save!, -> { flunk 'Mismatched IPA must not be claimed' }) do
        assert_raises(RuntimeError) { @release.begin_upload!(ipa: ipa) }
      end
    end
    assert_equal 'archived', @release.record['phase']
  end

end
