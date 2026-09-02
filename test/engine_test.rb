# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_site_root_types = RecordingStudioSiteSettings.configuration.site_root_types.dup
  end

  def teardown
    RecordingStudioSiteSettings.configuration.site_root_types = @original_site_root_types
  end

  def test_load_config_applies_site_root_types
    RecordingStudioSiteSettings.configuration.merge!(site_root_types: ["Tenant"])

    assert_equal ["Tenant"], RecordingStudioSiteSettings.configuration.site_root_types
  end
end
