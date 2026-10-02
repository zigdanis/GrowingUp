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
      @release.stub(:save!, -> { @saved = @release.record.dup }) { @release.prepare! }
    end
  end

  def prior_record(phase: 'uploading', source: 'a' * 40)
    { 'release_id' => '100', 'source_sha' => source, 'version' => '2.1.11', 'build_number' => '31',
      'app_id' => 'app', 'group_id' => 'group', 'tester_id' => 'danis', 'phase' => phase,
      'notes' => { 'en-US' => 'Original notes', 'ru' => 'Исходные заметки' } }
  end

  def test_allocates_above_processed_uploading_and_reserved_builds
    reserve([prior_record.merge('release_id' => '90', 'source_sha' => 'b' * 40, 'build_number' => '35')])
    assert_equal '36', @saved['build_number']
    assert_equal '2.1.11', @saved['version']
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

  def test_retry_refuses_different_source_or_recipient
    assert_raises(RuntimeError) { reserve([prior_record(source: 'b' * 40)]) }
    assert_raises(RuntimeError) { reserve([prior_record.merge('tester_id' => 'someone-else')]) }
  end

  def test_upload_intent_prevents_duplicate_after_runner_failure
    reserve
    @release.stub(:save!, nil) { @release.begin_upload! }
    @release.stub(:exact_build, nil) { refute @release.upload_needed? }
    assert_raises(RuntimeError) { @release.begin_upload! }
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

  def test_explicit_marketing_version_must_advance
    @env['MARKETING_VERSION'] = '2.1.10'
    assert_raises(RuntimeError) { reserve }
    @env['MARKETING_VERSION'] = '2.2.0'
    reserve
    assert_equal '2.2.0', @saved['version']
  end

  def test_missing_resume_receipt_never_reserves_another_build
    @env['RESUME_RUN_ID'] = '90'
    @release = TestflightRelease.new(@env)
    assert_raises(RuntimeError) { reserve }
    assert_nil @saved
  end
end
