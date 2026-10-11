require 'tmpdir'
require 'fileutils'
require 'fastlane'
require 'xcodeproj'

Dir.mktmpdir('growingup-signing-test-') do |directory|
  original = File.expand_path('../../GrowingUp.xcodeproj', __dir__)
  project_path = File.join(directory, 'GrowingUp.xcodeproj')
  FileUtils.cp_r(original, project_path)
  before = Xcodeproj::Project.open(project_path)
  unchanged = before.targets.flat_map do |target|
    target.build_configurations.filter_map do |configuration|
      next if %w[GrowingUp Widget].include?(target.name) && configuration.name == 'Release'
      [target.name, configuration.name, configuration.build_settings.dup]
    end
  end
  profiles = {
    'pro.ziganshin.GrowingUp' => 'match AppStore pro.ziganshin.GrowingUp GrowingUp CI 20261004',
    'pro.ziganshin.GrowingUp.Widget' => 'match AppStore pro.ziganshin.GrowingUp.Widget GrowingUp CI 20261004'
  }
  Fastlane.load_actions
  fastfile = Fastlane::FastFile.new(File.expand_path('../Fastfile', __dir__))
  fastfile.configure_release_signing(project_path, profiles)

  after = Xcodeproj::Project.open(project_path)
  %w[GrowingUp Widget].each do |name|
    target = after.targets.find { |candidate| candidate.name == name }
    settings = target.build_configurations.find { |configuration| configuration.name == 'Release' }.build_settings
    expected = profiles.fetch(settings.fetch('PRODUCT_BUNDLE_IDENTIFIER'))
    raise "#{name} archive profile differs from Match's installed profile" unless settings['PROVISIONING_PROFILE_SPECIFIER'] == expected
    raise "#{name} Release signing must remain manual" unless settings['CODE_SIGN_STYLE'] == 'Manual'
  end
  unchanged.each do |name, configuration_name, settings|
    target = after.targets.find { |candidate| candidate.name == name }
    actual = target.build_configurations.find { |configuration| configuration.name == configuration_name }.build_settings
    raise "Unexpected change to #{name} #{configuration_name}" unless settings == actual
  end
end
puts 'Release signing checks passed.'
