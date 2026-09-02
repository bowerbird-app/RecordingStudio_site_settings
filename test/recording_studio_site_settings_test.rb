# frozen_string_literal: true

require "test_helper"

class RecordingStudioSiteSettingsTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RecordingStudioSiteSettings::VERSION
    assert_equal "0.1.0", ::RecordingStudioSiteSettings::VERSION
  end

  def test_readme_is_the_public_product
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "# Recording Studio Site Settings"
    assert_includes readme, "source of truth"
    assert_includes readme, "name_for"
    assert_includes readme, "logo_for"
    refute_includes readme, "Gem Template"
    refute_includes readme, "recording_studio_gem_template"
  end

  def test_gemspec_pins_live_majors
    gemspec = File.read(File.expand_path("../recording_studio_site_settings.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.8"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_admin", "~> 2.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_attachable", "~> 0.5"'
    assert_includes gemspec, 'spec.homepage = "https://github.com/bowerbird-app/RecordingStudio_site_settings"'
  end

  def test_cursor_is_not_in_the_gemspec
    gemspec = File.read(File.expand_path("../recording_studio_site_settings.gemspec", __dir__))

    refute_includes gemspec, ".cursor"
  end
end
