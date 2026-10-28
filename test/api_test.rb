# frozen_string_literal: true

require "test_helper"

class ApiTest < Minitest::Test
  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)
    assert_nil RecordingStudioSiteSettings::Api.register!
  end

  def test_gemspec_omits_recording_studio_api_runtime_dependency
    gemspec = File.read(File.expand_path("../recording_studio_site_settings.gemspec", __dir__))

    refute_includes gemspec, '"recording_studio_api"'
  end

  def test_engine_registers_api_in_to_prepare
    engine = File.read(File.expand_path("../lib/recording_studio_site_settings/engine.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_site_settings.api"'
    assert_includes engine, "config.to_prepare { RecordingStudioSiteSettings::Api.register! }"
  end

  def test_update_input_reads_file_objects_urls_and_clears
    input = RecordingStudioSiteSettings::Api::UpdateInput.parse!(
      square_logo_file: " https://cdn.example.com/square.png ",
      "wide_logo_file" => { download_url: "https://files.example.com/x", file_id: "file_123", mime_type: "image/png",
                            file_name: "wide.png" },
      favicon_file: nil
    )

    refute input.name_given?
    expected = { "square_logo" => "https://cdn.example.com/square.png", "wide_logo" => "https://files.example.com/x" }
    assert_equal expected, input.sources
    assert_equal ["favicon"], input.clears
  end

  def test_update_input_file_fields_follow_mark_variants
    expected = RecordingStudioSiteSettings::Admin::MARK_VARIANTS.keys.to_h { |slot| [:"#{slot}_file", slot] }

    assert_equal expected, RecordingStudioSiteSettings::Api::UpdateInput.file_fields
  end

  def test_update_input_strips_a_given_name
    input = RecordingStudioSiteSettings::Api::UpdateInput.parse!(name: "  Studio  ")

    assert input.name_given?
    assert_equal "Studio", input.name
  end
end
