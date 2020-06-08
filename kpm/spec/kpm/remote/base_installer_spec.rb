# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe KPM::BaseInstaller do
  before(:all) do
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end

  it 'should be able to uninstall via plugin key' do
    Dir.mktmpdir do |dir|
      bundles_dir = dir + '/bundles'
      installer = KPM::BaseInstaller.new(@logger)

      installer.install_plugin('analytics', nil, nil, nil, nil, nil, '0.7.1', bundles_dir)

      check_installation(bundles_dir)

      installer.uninstall_plugin('analytics', nil, bundles_dir)

      check_uninstallation(bundles_dir)
    end
  end

  # See https://github.com/killbill/killbill-cloud/issues/14
  it 'should be able to uninstall via plugin name' do
    Dir.mktmpdir do |dir|
      bundles_dir = dir + '/bundles'
      installer = KPM::BaseInstaller.new(@logger)

      installer.install_plugin('analytics', nil, nil, nil, nil, nil, '0.7.1', bundles_dir)

      check_installation(bundles_dir)

      installer.uninstall_plugin('analytics-plugin', nil, bundles_dir)

      check_uninstallation(bundles_dir)
    end
  end

  it 'should raise an exception when plugin does not exist' do
    Dir.mktmpdir do |dir|
      bundles_dir = dir + '/bundles'
      installer = KPM::BaseInstaller.new(@logger)

      begin
        installer.install_plugin('invalid', nil, nil, nil, nil, nil, '1.2.3', bundles_dir)
        raise 'Should not succeed to install invalid plugin'
      rescue ArgumentError
        # Expected
      end
    end
  end

  it 'should extract plugin name from file path' do
    [
      { file_path: '/Somewhere/xxx-foo/target/xxx-1.0.0.jar', expected: 'xxx' },
      { file_path: '/Somewhere/xxx-foo/target/xxx-foo-bar-1.0.0.jar', expected: 'xxx-foo-bar' },
      { file_path: '/Somewhere/xxx-foo/target/xxx-foo-1.0.0.jar', expected: 'xxx-foo' },
      { file_path: '/Somewhere/xxx-foo/target/xxx-foo-1.0.0-SNAPSHOT.jar', expected: 'xxx-foo' },
      { file_path: '/Somewhere/xxx-foo/target/xxx-foo-1.0.jar', expected: 'xxx-foo' },
      { file_path: '/Somewhere/xxx-foo/target/xxx-foo-1.jar', expected: 'xxx-foo' },
      { file_path: '/Somewhere/xxx-foo/target/xxx-foo-abc-SNAPSHOT.jar', expected: 'xxx-foo' },
      { file_path: '/Somewhere/xxx-foo/target/xxx-foo-abc.jar', expected: 'xxx-foo' }
    ].each do |test|
      KPM::Utils.get_plugin_name_from_file_path(test[:file_path]).should eq test[:expected]
    end
  end

  private

  def check_installation(plugins_dir)
    common_checks(plugins_dir)

    plugin_identifiers = read_plugin_identifiers(plugins_dir)

    plugin_identifiers.size.should eq 1

    plugin_identifiers['analytics']['plugin_name'].should eq 'analytics-plugin'
    plugin_identifiers['analytics']['group_id'].should eq 'org.kill-bill.billing.plugin.java'
    plugin_identifiers['analytics']['artifact_id'].should eq 'analytics-plugin'
    plugin_identifiers['analytics']['packaging'].should eq 'jar'
    plugin_identifiers['analytics']['version'].should eq '0.7.1'
    plugin_identifiers['analytics']['language'].should eq 'java'

    File.file?(plugins_dir + '/plugins/java/analytics-plugin/0.7.1/tmp/disabled.txt').should be_false
  end

  def check_uninstallation(plugins_dir)
    common_checks(plugins_dir)

    plugin_identifiers = read_plugin_identifiers(plugins_dir)

    plugin_identifiers.size.should eq 0

    File.file?(plugins_dir + '/plugins/java/analytics-plugin/0.7.1/tmp/disabled.txt').should be_true
  end

  def common_checks(plugins_dir)
    [
      plugins_dir,
      plugins_dir + '/plugins',
      plugins_dir + '/plugins/java',
      plugins_dir + '/plugins/java/analytics-plugin',
      plugins_dir + '/plugins/java/analytics-plugin/0.7.1',
      plugins_dir + '/plugins/java/analytics-plugin/0.7.1/tmp'
    ].each do |dir|
      File.directory?(dir).should be_true
    end

    [
      plugins_dir + '/plugins/plugin_identifiers.json',
      plugins_dir + '/plugins/java/analytics-plugin/0.7.1/analytics-plugin-0.7.1.jar'
    ].each do |file|
      File.file?(file).should be_true
    end
  end

  def read_plugin_identifiers(plugins_dir)
    File.open(plugins_dir + '/plugins/plugin_identifiers.json', 'r') do |f|
      JSON.parse(f.read)
    end
  end
end
