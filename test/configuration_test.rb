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
end
