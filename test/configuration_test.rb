# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @original_site_root_types = RecordingStudioSiteSettings.configuration.site_root_types.dup
    @original_resolver = RecordingStudioSiteSettings.configuration.site_root_resolver
  end

  def teardown
    RecordingStudioSiteSettings.configuration.site_root_types = @original_site_root_types
    RecordingStudioSiteSettings.configuration.site_root_resolver = @original_resolver
  end

  def test_fresh_configuration_defaults_to_workspace
    assert_equal ["Workspace"], RecordingStudioSiteSettings::Configuration.new.site_root_types
  end

  def test_default_site_root_types
    RecordingStudioSiteSettings.configuration.site_root_types = ["Workspace"]

    assert_equal ["Workspace"], RecordingStudioSiteSettings.configuration.site_root_types
  end

  def test_merge_from_hash_updates_site_root_types
    RecordingStudioSiteSettings.configuration.merge!(site_root_types: ["Account"])

    assert_equal ["Account"], RecordingStudioSiteSettings.configuration.site_root_types
  end

  def test_remote_image_allowed_networks_parse_strings_and_arrays
    config = RecordingStudioSiteSettings::Configuration.new
    assert_empty config.remote_image_allowed_networks

    config.remote_image_allowed_networks = "198.18.0.0/15, 100.64.0.0/10"
    assert_equal 2, config.remote_image_allowed_networks.size
    assert config.remote_image_allowed_networks.first.include?(IPAddr.new("198.19.1.1"))

    config.remote_image_allowed_networks = ["198.18.0.0/15"]
    assert_equal ["198.18.0.0/15"], config.to_h[:remote_image_allowed_networks]
  end
end
