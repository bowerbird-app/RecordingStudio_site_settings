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
    readme = File.read(File.expand_path("../README.md", __dir__))
    dummy_gemfile = File.read(File.expand_path("../test/dummy/Gemfile", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.8"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.9"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_admin", "~> 2.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_attachable", "~> 0.5"'
    assert_includes readme, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.0"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.0"'
    assert_match(
      %r{spec\.homepage\s+=\s+"https://github.com/bowerbird-app/RecordingStudio_site_settings"},
      gemspec
    )
  end

  def test_cursor_is_not_in_the_gemspec
    spec = Gem::Specification.load(File.expand_path("../recording_studio_site_settings.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files
  end

  def test_admin_form_uses_grid_cols_2_as_a_width_cap
    view = File.read(
      File.expand_path(
        "../app/views/recording_studio_site_settings/admin/settings/show.html.erb",
        __dir__
      )
    )

    assert_includes view, "FlatPack::Grid::Component.new(cols: 2)"
    assert_includes view, "form_with url: settings_path"
    assert_includes view, "FlatPack::Grid::Component.new(cols: 1, gap: :lg)"
    assert_includes view, 'turbo_frame_tag "site-logo"'
    assert_includes view, "render_attachment_file_button(@site_setting_recording, return_to: settings_path)"
    assert_includes view, "attachment_preview_url(@site_setting_recording, variant: :square_med)"
    assert_includes view, "shape: :square"
    refute_includes view, "FileInput"
    refute_includes view, "Upload a file or drag and drop"
    assert_includes view, "recording_studio_page_nav"
    assert_includes view, "page_nav_anchor_url: main_app.root_path"
    refute_includes view, "page_nav_back_url"
  end

  def test_dummy_tailwind_imports_generated_gem_sources
    css = File.read(File.expand_path("../test/dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes css, '@import "./gem_sources.css"'
  end

  def test_admin_controller_uses_core_default_layout
    source = File.read(
      File.expand_path(
        "../app/controllers/recording_studio_site_settings/application_controller.rb",
        __dir__
      )
    )

    assert_includes source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes source, 'layout "recording_studio/default_layout"'
  end
end
