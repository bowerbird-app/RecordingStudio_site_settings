# frozen_string_literal: true

require "test_helper"

class SiteSettingsHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  HOST_SAVED = "HOST Saved. That's this site's name, logos, and tab icon."
  HOST_SQUARE_ALT = "HOST square-logo alt"
  HOST_WIDE_ALT = "HOST wide-logo alt"
  GEM_SQUARE_ALT = "Square logo"
  GEM_WIDE_ALT = "Wide logo"
  SAVED_KEY = "recording_studio.site_settings.flashes.saved"
  SQUARE_ALT_KEY = "recording_studio.site_settings.helpers.square_logo_alt"
  WIDE_ALT_KEY = "recording_studio.site_settings.helpers.wide_logo_alt"
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/site_settings_host_override.en.yml")
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_site_settings_boot_override.en.yml")

  setup do
    @load_path_before = I18n.load_path.dup
    @admin = create_user("host-override-admin-#{SecureRandom.hex(4)}@example.com")
    @studio_root = workspace_root("Host Override Studio #{SecureRandom.hex(4)}")
    @site_root = admin_root_recording
    grant_site_settings_admin!(@admin, workspace_root: @studio_root)
    RecordingStudioSiteSettings.update!(@site_root, name: "Host Override Site", actor: @admin)
  end

  teardown do
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  # Real-boot-order guard: always-loaded dummy override wins for real, rarely
  # shown helper alt keys, asserted on a real probe render of those keys.
  test "boot-order host override for helper alts wins on real render" do
    assert File.exist?(BOOT_HOST_LOCALE)
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_SQUARE_ALT
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_WIDE_ALT
    assert_equal HOST_SQUARE_ALT, I18n.t(SQUARE_ALT_KEY)
    assert_equal HOST_WIDE_ALT, I18n.t(WIDE_ALT_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    get "/locale_probes/helper_alts"
    assert_response :success
    assert_equal "#{HOST_SQUARE_ALT}\n#{HOST_WIDE_ALT}", response.body
    refute_includes response.body, GEM_SQUARE_ALT
    refute_includes response.body, GEM_WIDE_ALT
  end

  # Test-only fixture loaded into a fresh Simple backend — never mutates
  # I18n.load_path. Visible flashes are overridden here (not via always-loaded file).
  test "fresh-backend last-file-wins host fixture overrides gem english on save notice and helper alts" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_SAVED
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_SQUARE_ALT
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_WIDE_ALT

    sign_in @admin
    switch_root!(@studio_root)

    previous_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations
    I18n.t(SAVED_KEY)
    I18n.backend.load_translations(FRESH_HOST_LOCALE.to_s)

    assert_equal @load_path_before, I18n.load_path
    assert_equal HOST_SAVED, I18n.t(SAVED_KEY)
    assert_equal HOST_SQUARE_ALT, I18n.t(SQUARE_ALT_KEY)
    assert_equal HOST_WIDE_ALT, I18n.t(WIDE_ALT_KEY)

    get "/locale_probes/helper_alts"
    assert_response :success
    assert_equal "#{HOST_SQUARE_ALT}\n#{HOST_WIDE_ALT}", response.body
    refute_includes response.body, GEM_SQUARE_ALT
    refute_includes response.body, GEM_WIDE_ALT

    patch recording_studio_site_settings.settings_path, params: {
      site_setting: { name: "Host Override Wins" }
    }

    assert_redirected_to recording_studio_site_settings.settings_path
    follow_redirect!
    assert_includes unescaped_page, HOST_SAVED
  ensure
    I18n.backend = previous_backend
    I18n.reload!
  end

  private

  def unescaped_page
    CGI.unescapeHTML(response.body)
  end
end
