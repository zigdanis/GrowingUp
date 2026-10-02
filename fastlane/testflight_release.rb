require 'json'
require 'net/http'
require 'open3'
require 'uri'
require 'rubygems/version'

# A private draft release stores each receipt in one durable API mutation.
class TestflightRelease
  APP_ID = 'pro.ziganshin.GrowingUp'
  WIDGET_ID = "#{APP_ID}.Widget"
  PREFIX = 'testflight/receipts/'
  attr_reader :record, :group, :app, :inventory

  def initialize(env = ENV)
    @env = env
    @repo = env.fetch('GITHUB_REPOSITORY')
    @release_id = env['RESUME_RUN_ID'].to_s.empty? ? env.fetch('GITHUB_RUN_ID') : env['RESUME_RUN_ID']
    raise 'Invalid release run ID' unless @release_id.match?(/\A\d+\z/)
    @record = { 'workflow_url' => "https://github.com/#{@repo}/actions/runs/#{env.fetch('GITHUB_RUN_ID')}" }
  end

  def self.next_version(versions)
    latest = versions.map { |v| Gem::Version.new(v) }.max
    parts = latest.segments.values_at(0, 1, 2).map { |p| p || 0 }
    parts[2] += 1
    parts.join('.')
  end

  def self.next_build(numbers)
    # Advancing the leading integer also exceeds historic dotted build numbers.
    numbers.map { |n| Integer(n.to_s.split('.').first, 10) }.max.to_i + 1
  end

  def github(path, method: 'GET', data: nil, paginate: false)
    command = ['gh', 'api', "repos/#{@repo}/#{path}", '--method', method]
    command += ['--input', '-'] if data
    command += ['--paginate', '--slurp'] if paginate
    (method == 'GET' ? 3 : 1).times do
      output, _error, status = Open3.capture3(*command, stdin_data: data ? JSON.generate(data) : '')
      return output.empty? ? nil : JSON.parse(output) if status.success?
    end
    raise "GitHub #{method} #{path} failed; inspect authentication/network and retry the same release"
  end

  def asc(path, params = {})
    url = URI("https://api.appstoreconnect.apple.com#{path}")
    url.query = URI.encode_www_form(params) unless params.empty?
    resources = []
    included = []
    loop do
      raise 'Unexpected Apple pagination host' unless url.host == 'api.appstoreconnect.apple.com' && url.scheme == 'https'
      token = Spaceship::ConnectAPI.token
      token.refresh! if token.expired?
      request = Net::HTTP::Get.new(url)
      request['Authorization'] = "Bearer #{token.text}"
      response = Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 30, read_timeout: 60) { |http| http.request(request) }
      unless response.is_a?(Net::HTTPSuccess)
        errors = begin
          JSON.parse(response.body.to_s).fetch('errors', []).map { |e| [e['code'], e['title'], e['detail']].compact.join(': ') }
        rescue JSON::ParserError
          []
        end
        raise "Apple API #{path} returned HTTP #{response.code}: #{errors.join('; ')}"
      end
      body = JSON.parse(response.body)
      resources.concat(body.fetch('data').is_a?(Array) ? body['data'] : [body['data']])
      included.concat(body.fetch('included', []))
      break unless body.dig('links', 'next')
      url = URI(body['links']['next'])
    end
    [resources, included]
  end

  def preflight!(configure: true)
    apps, = asc('/v1/apps', 'filter[bundleId]' => APP_ID)
    raise 'GrowingUp app record not found or ambiguous' unless apps.length == 1
    @app = apps.first
    groups, = asc("/v1/apps/#{app['id']}/betaGroups")
    @inventory = { 'app_id' => app['id'], 'groups' => [] }
    groups.each do |candidate|
      inventory['groups'] << {
        'id' => candidate['id'], 'name' => candidate.dig('attributes', 'name'),
        'internal' => candidate.dig('attributes', 'isInternalGroup')
      }
    end
    @group = groups.find { |g| g['id'] == @env['BETA_GROUP_ID'] }
    @group ||= groups.find { |g| g.dig('attributes', 'name') == 'External' } if @env['BETA_GROUP_ID'].to_s.empty?
    @group ||= groups.first if groups.length == 1 && @env['BETA_GROUP_ID'].to_s.empty?
    write_report
    raise 'Set BETA_GROUP_ID to an existing group from the preflight inventory' unless group
    resolve_tester!
    members, = asc("/v1/betaGroups/#{group['id']}/betaTesters", 'limit' => 200)
    if configure && !members.any? { |t| t['id'] == @tester_id }
      Spaceship::ConnectAPI.add_beta_tester_to_group(beta_group_id: group['id'], beta_tester_ids: [@tester_id])
    end
    unless internal?
      details, = asc("/v1/apps/#{app['id']}/betaAppReviewDetail")
      override = review_info
      missing = %w[contactFirstName contactLastName contactPhone contactEmail].reject do |key|
        snake = key.gsub(/[A-Z]/) { |c| "_#{c.downcase}" }
        !override.fetch(snake, details.first&.dig('attributes', key)).to_s.empty?
      end
      raise "Missing beta review fields: #{missing.join(', ')}; supply BETA_REVIEW_INFO as an encrypted JSON secret" unless missing.empty?
      localizations, = asc("/v1/apps/#{app['id']}/betaAppLocalizations")
      @feedback_email = @env['BETA_FEEDBACK_EMAIL'].to_s
      @feedback_email = localizations.map { |l| l.dig('attributes', 'feedbackEmail') }.find { |e| !e.to_s.empty? } if @feedback_email.empty?
      raise 'Missing feedback email; supply BETA_FEEDBACK_EMAIL as an Actions secret' if @feedback_email.to_s.empty?
    end
    @builds, = asc('/v1/builds', 'filter[app]' => app['id'], 'limit' => 200)
    @uploads, = asc("/v1/apps/#{app['id']}/buildUploads", 'limit' => 200)
    trains, = asc('/v1/preReleaseVersions', 'filter[app]' => app['id'], 'limit' => 200)
    store_versions, = asc("/v1/apps/#{app['id']}/appStoreVersions", 'filter[platform]' => 'IOS', 'limit' => 200)
    @versions = (trains + store_versions).map { |v| v.dig('attributes', v['type'] == 'appStoreVersions' ? 'versionString' : 'version') }
    @versions += @uploads.map { |u| u.dig('attributes', 'cfBundleShortVersionString') }
    @versions << @env.fetch('PROJECT_VERSION')
    @versions = @versions.compact
    inventory['next_version'] = self.class.next_version(@versions)
    inventory['selected_group_id'] = group['id']
    inventory['selected_tester_id'] = @tester_id
    write_report
  end

  def internal?
    group.dig('attributes', 'isInternalGroup')
  end

  def review_info
    raw = @env['BETA_REVIEW_INFO'].to_s
    return {} if raw.strip.empty?
    info = JSON.parse(raw)
    allowed = %w[contact_first_name contact_last_name contact_email contact_phone notes]
    unless info.is_a?(Hash) && (info.keys - allowed).empty? && info.values.all? { |value| value.is_a?(String) }
      raise 'BETA_REVIEW_INFO needs a JSON object with beta review contact fields'
    end
    if @env['GITHUB_ACTIONS'] == 'true'
      info.values.reject(&:empty?).each do |value|
        # Register each scalar with the runner: whole-JSON secret masking does
        # not protect individual values in Apple's validation messages.
        escaped = value.gsub('%', '%25').gsub("\r", '%0D').gsub("\n", '%0A')
        puts "::add-mask::#{escaped}"
      end
    end
    info
  rescue JSON::ParserError
    raise 'BETA_REVIEW_INFO contains invalid JSON; no credential values are shown', cause: nil
  end

  def resolve_tester!
    if !@env['BETA_TESTER_ID'].to_s.empty?
      testers, = asc("/v1/betaTesters/#{@env['BETA_TESTER_ID']}")
    elsif !@env['BETA_TESTER_EMAIL'].to_s.empty?
      testers, = asc('/v1/betaTesters', 'filter[email]' => @env['BETA_TESTER_EMAIL'], 'limit' => 200)
    else
      testers, = asc('/v1/betaTesters', 'filter[apps]' => app['id'], 'limit' => 200)
    end
    matches = testers.select do |tester|
      if !@env['BETA_TESTER_ID'].to_s.empty?
        tester['id'] == @env['BETA_TESTER_ID']
      elsif !@env['BETA_TESTER_EMAIL'].to_s.empty?
        tester.dig('attributes', 'email').to_s.downcase == @env['BETA_TESTER_EMAIL'].downcase
      else
        %w[danis данис].include?(tester.dig('attributes', 'firstName').to_s.downcase)
      end
    end
    raise 'Cannot identify Danis uniquely; supply his BETA_TESTER_ID or an encrypted BETA_TESTER_EMAIL secret' unless matches.length == 1
    @tester_id = matches.first['id']
  end

  def records
    github('releases?per_page=100', paginate: true).flatten.select { |r| r['draft'] && r['tag_name'].start_with?(PREFIX) }.map do |release|
      JSON.parse(release.fetch('body')).merge('receipt_id' => release.fetch('id'))
    end
  end

  def prepare!
    previous = records
    existing = previous.find { |r| r['release_id'] == @release_id }
    if existing
      raise 'Release source differs from its recorded source' unless existing['source_sha'] == @env.fetch('SOURCE_SHA')
      unless existing['group_id'] == group['id'] && existing['tester_id'] == @tester_id && existing['app_id'] == app['id']
        raise 'Recorded release app/group/tester differs from current preflight; restore the intended settings before resuming'
      end
      @record = existing.merge('workflow_url' => record['workflow_url'])
      write_report
      return
    end
    raise 'No recorded release for RESUME_RUN_ID' unless @env['RESUME_RUN_ID'].to_s.empty?
    requested = @env.fetch('MARKETING_VERSION')
    versions = @versions + previous.map { |r| r.fetch('version') }
    version = requested == 'next' ? self.class.next_version(versions) : requested
    raise 'Marketing version must be numeric (one to three components)' unless version.match?(/\A\d+(?:\.\d+){0,2}\z/)
    raise 'Each new deployment must advance the marketing version' unless Gem::Version.new(version) > versions.map { |v| Gem::Version.new(v) }.max
    pending = previous.find { |r| r['source_sha'] == @env['SOURCE_SHA'] && !%w[available processing_failed distribution_failed].include?(r['phase']) }
    raise "This source already has a pending release; resume run #{pending['release_id']}" if pending
    notes = { 'en-US' => @env.fetch('NOTES_EN'), 'ru' => @env.fetch('NOTES_RU') }
    raise 'Provide nonempty EN/RU notes, each at most 4000 UTF-8 bytes' unless notes.values.all? { |n| !n.strip.empty? && n.bytesize <= 4000 }
    numbers = @builds.map { |b| b.dig('attributes', 'version') } + @uploads.map { |u| u.dig('attributes', 'cfBundleVersion') }
    numbers += previous.map { |r| r.fetch('build_number') } + [@env.fetch('PROJECT_BUILD')]
    @record.merge!('release_id' => @release_id, 'source_sha' => @env.fetch('SOURCE_SHA'),
                   'version' => version, 'build_number' => self.class.next_build(numbers.compact).to_s,
                   'app_id' => app['id'], 'group_id' => group['id'], 'tester_id' => @tester_id,
                   'notes' => notes, 'phase' => 'reserved')
    save!
  end

  def save!
    data = { tag_name: "#{PREFIX}#{@release_id}", target_commitish: 'master',
             name: "TestFlight receipt: #{record.fetch('version')} (#{record.fetch('build_number')})",
             body: JSON.generate(record), draft: true, prerelease: true }
    path = record['receipt_id'] ? "releases/#{record['receipt_id']}" : 'releases'
    saved = github(path, method: record['receipt_id'] ? 'PATCH' : 'POST', data: data)
    record['receipt_id'] = saved.fetch('id')
    write_report
  end

  def exact_build
    builds, included = asc('/v1/builds', 'filter[app]' => app['id'], 'filter[version]' => record.fetch('build_number'),
                           'filter[preReleaseVersion.version]' => record.fetch('version'), 'include' => 'buildBetaDetail,preReleaseVersion')
    raise 'Multiple builds match the release identity' if builds.length > 1
    build = builds.first
    if build
      detail_id = build.dig('relationships', 'buildBetaDetail', 'data', 'id')
      build['beta_detail'] = included.find { |i| i['id'] == detail_id && i['type'] == 'buildBetaDetails' }
    end
    build
  end

  def upload_needed?
    return false if exact_build
    # An upload intent is committed BEFORE invoking Transporter. Uncertain results
    # are polled, never blindly uploaded again, even after cancellation.
    record.fetch('phase') == 'reserved'
  end

  def begin_upload!
    raise 'This release already attempted an upload' unless record.fetch('phase') == 'reserved'
    record['phase'] = 'uploading'
    save!
  end

  def uploaded!
    record['phase'] = 'uploaded'
    save!
  end

  def wait_for_processing!
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1200
    loop do
      build = exact_build
      state = build&.dig('attributes', 'processingState')
      unless build
        uploads, = asc("/v1/apps/#{app['id']}/buildUploads", 'limit' => 200)
        upload = uploads.find do |u|
          u.dig('attributes', 'cfBundleVersion') == record['build_number'] &&
            u.dig('attributes', 'cfBundleShortVersionString') == record['version']
        end
        if upload&.dig('attributes', 'state', 'state') == 'FAILED'
          record.merge!('phase' => 'processing_failed', 'processing_status' => 'UPLOAD_FAILED',
                         'processing_errors' => upload.dig('attributes', 'state', 'errors'))
          save!
          raise 'Apple rejected the upload; inspect processing_errors in the release receipt before a corrected release'
        end
      end
      if %w[FAILED INVALID].include?(state)
        record.merge!('phase' => 'processing_failed', 'processing_status' => state)
        save!
        raise "Apple rejected processing of #{record['version']} (#{record['build_number']}); inspect App Store Connect diagnostics"
      end
      if state == 'VALID'
        if build.dig('attributes', 'usesNonExemptEncryption').nil?
          Spaceship::ConnectAPI::Build.get(build_id: build['id']).update(attributes: { uses_non_exempt_encryption: false })
        end
        record.merge!('processing_status' => state, 'apple_build_id' => build['id'])
        return build
      end
      raise 'Apple processing/visibility is still pending. Resume this release; do not dispatch another upload.' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      puts "Waiting for exact build #{record['version']} (#{record['build_number']}): #{state || 'not visible'}"
      sleep 30
    end
  end

  def pilot_options
    options = { app_identifier: APP_ID, apple_id: app['id'], app_version: record.fetch('version'),
                build_number: record.fetch('build_number'), distribute_only: true, distribute_external: !internal?,
                groups: internal? && group.dig('attributes', 'hasAccessToAllBuilds') ? nil : [group['id']],
                submit_beta_review: !internal?, notify_external_testers: !internal?,
                localized_build_info: record.fetch('notes').transform_values { |text| { whats_new: text } },
                demo_account_required: false }
    unless internal?
      options[:localized_app_info] = {
        'en-US' => { feedback_email: @feedback_email, description: 'Track the ages of people you care about, with photos and a Home Screen widget.' },
        'ru' => { feedback_email: @feedback_email, description: 'Следите за возрастом близких: фотографии и виджет на главном экране.' }
      }
      override = review_info
      unless override.empty?
        attributes = override.transform_keys { |key| key.gsub(/_([a-z])/) { Regexp.last_match(1).upcase } }
        Spaceship::ConnectAPI.patch_beta_app_review_detail(app_id: app['id'], attributes: attributes)
      end
    end
    options
  end

  def verify_distribution!
    build = exact_build
    raise 'Exact uploaded build disappeared' unless build
    group_builds, = asc("/v1/betaGroups/#{group['id']}/builds", 'limit' => 200)
    assigned = group_builds.any? { |b| b['id'] == build['id'] }
    assigned ||= internal? && group.dig('attributes', 'hasAccessToAllBuilds')
    testers, = asc("/v1/betaGroups/#{group['id']}/betaTesters", 'limit' => 200)
    raise 'Danis is no longer a member of the release group' unless testers.any? { |t| t['id'] == @tester_id }
    state = build.dig('beta_detail', 'attributes', internal? ? 'internalBuildState' : 'externalBuildState')
    ready = assigned && state == 'IN_BETA_TESTING'
    notified = internal? || build.dig('beta_detail', 'attributes', 'autoNotifyEnabled')
    failed = %w[BETA_REJECTED EXPIRED PROCESSING_EXCEPTION].include?(state)
    phase = failed ? 'distribution_failed' : (ready ? 'available' : 'awaiting_apple_review')
    record.merge!('phase' => phase, 'distribution_status' => state,
                   'group_assigned' => !!assigned, 'notification_enabled' => !!notified, 'tester_id' => @tester_id)
    save!
    raise "Apple beta distribution failed: #{state}" if failed
    raise 'External tester notifications are disabled' unless notified
  end

  def status!
    build = exact_build
    record['processing_status'] = build ? build.dig('attributes', 'processingState') : 'NOT_VISIBLE'
    if record['processing_status'] == 'VALID'
      verify_distribution!
    else
      save!
    end
  end

  def write_report
    path = @env.fetch('RELEASE_RECEIPT')
    File.write(path, JSON.pretty_generate(record.merge('preflight' => inventory)) + "\n")
    return unless @env['GITHUB_STEP_SUMMARY']
    File.write(@env['GITHUB_STEP_SUMMARY'], "### GrowingUp TestFlight\n\n```json\n#{JSON.pretty_generate(record.merge('preflight' => inventory))}\n```\n\nDevice receipt still requires Danis's confirmation.\n")
  end
end
