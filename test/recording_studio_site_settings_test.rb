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
    assert_includes readme, "square_logo_for"
    assert_includes readme, "wide_logo_for"
    assert_includes readme, "logo_for"
    assert_includes readme, "favicon_for"
    assert_includes readme, "recording_studio_site_square_logo"
    assert_includes readme, "recording_studio_site_wide_logo"
    assert_includes readme, "recording_studio_site_favicon"
    refute_includes readme, "Gem Template"
    refute_includes readme, "recording_studio_gem_template"
  end

  def test_gemspec_pins_live_majors
    gemspec = File.read(File.expand_path("../recording_studio_site_settings.gemspec", __dir__))
    readme = File.read(File.expand_path("../README.md", __dir__))
    dummy_gemfile = File.read(File.expand_path("../test/dummy/Gemfile", __dir__))

    assert_includes gemspec, 'spec.add_dependency "flat_pack", ">= 0.1.144"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.8"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.9"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_admin", "~> 2.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_attachable", "~> 0.5"'
    assert_includes readme, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.0"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.0"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.144"'
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
    assert_includes view, 'turbo_frame_tag "site-square-logo"'
    assert_includes view, 'turbo_frame_tag "site-wide-logo"'
    assert_includes view, 'turbo_frame_tag "site-favicon"'
    assert_includes view, 'slot: "square_logo"'
    assert_includes view, 'slot: "wide_logo"'
    assert_includes view, 'slot: "favicon"'
    assert_includes view, "render_site_settings_file_button"
    assert_includes view, "@square_logo.preview_url"
    assert_includes view, "@wide_logo.preview_url"
    assert_includes view, "@favicon.preview_url"
    assert_includes view, "recording_studio_site_wide_logo"
    assert_includes view, 'size: :"2xl"'
    assert_includes view, "size: :xl"
    assert_includes view, "Browser tab."
    assert_includes view, "shape: :square"
    assert_includes view, 'icon: "photo"'
    refute_includes view, "<img src="
    refute_includes view, "render_attachment_file_button"
    refute_includes view, "attachment_preview_url"
    refute_includes view, "FileInput"
    refute_includes view, "Upload a file or drag and drop"
    refute_includes view, "md:grid-cols-3"
    assert_includes view, "recording_studio_page_nav"
    assert_includes view, "page_nav_anchor_url: main_app.root_path"
    refute_includes view, "page_nav_back_url"
    refute_includes view, "ButtonGroup"
    assert_includes view, 'html: { id: "site-name-form" }'
    assert_includes view, 'form: "site-name-form"'
    assert_includes view, 'text: "Save"'
    assert_includes view, 'text: "Cancel"'

    name_at = view.index('label: "Site name"')
    wide_at = view.index("Wide logo")
    square_at = view.index("Square logo")
    favicon_at = view.index("Favicon")
    save_at = view.index('text: "Save"')
    cancel_at = view.index('text: "Cancel"')

    assert name_at, "Site name field is missing"
    assert wide_at, "Wide logo row is missing"
    assert square_at, "Square logo row is missing"
    assert favicon_at, "Favicon row is missing"
    assert save_at, "Save is missing"
    assert cancel_at, "Cancel is missing"
    assert name_at < wide_at, "Site name must come before Wide logo"
    assert wide_at < square_at, "Wide logo must come before Square logo"
    assert square_at < favicon_at, "Square logo must come before Favicon"
    assert favicon_at < save_at, "Favicon must come before Save"
    assert save_at < cancel_at, "Save must come before Cancel"
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

  def test_dummy_layout_head_prints_favicon
    dummy_root = File.expand_path("../test/dummy", __dir__)
    head = File.read(File.join(dummy_root, "app/views/recording_studio/_default_layout_head.html.erb"))
    sidebar = File.read(File.join(dummy_root, "app/views/application/_wide_logo_sidebar.html.erb"))
    home = File.read(File.join(dummy_root, "app/views/home/index.html.erb"))
    docs_install = File.read(File.join(dummy_root, "app/views/docs/install.html.erb"))
    helper = File.read(File.join(dummy_root, "app/helpers/application_helper.rb"))
    button = File.read(
      File.expand_path(
        "../app/views/recording_studio_site_settings/admin/settings/_mark_file_button.html.erb",
        __dir__
      )
    )

    refute File.exist?(File.join(dummy_root, "app/views/layouts/recording_studio/default_layout.html.erb")),
           "dummy must not override core default_layout"
    refute File.exist?(File.join(dummy_root, "app/views/recording_studio/_site_marks.html.erb")),
           "dummy must not inject site_marks into layout"
    assert_includes head, "recording_studio_site_favicon"
    assert_includes head, "dummy_site_root_recording"
    assert_includes helper, "def dummy_site_root_recording"
    assert_includes helper, "def dummy_wide_logo_sidebar"
    assert_includes helper, "recording_studio_site_wide_logo"
    refute_includes helper, "current_root_recording"
    assert_includes sidebar, "dummy_sidebar_wide_logo"
    assert_includes sidebar, "FlatPack::Sidebar::Component"
    refute_includes sidebar, "SidebarLayout"
    assert_includes home, "dummy_wide_logo_sidebar"
    assert_includes docs_install, "dummy_wide_logo_sidebar"
    assert_includes button, "attachment_import[attachments][][name]"
    assert_includes button, "mark_name"
  end

  def test_public_helpers_include_favicon
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_site_settings/application_helper.rb", __dir__)
    )
    model = File.read(
      File.expand_path("../app/models/recording_studio_site_settings/site_setting.rb", __dir__)
    )

    assert_includes helper, "def recording_studio_site_favicon"
    assert_includes helper, "def recording_studio_site_square_logo"
    assert_includes helper, "def recording_studio_site_wide_logo"
    assert_includes helper, "def recording_studio_site_logo"
    refute_includes helper, "FileInput"
    assert_includes model, "max_file_count: 3"
  end
end
