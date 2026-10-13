# frozen_string_literal: true

require "test_helper"

class SiteSettingsHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  HOST_SAVED = "HOST Saved. That's this site's name, logos, and tab icon."
  SAVED_KEY = "recording_studio.site_settings.flashes.saved"
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/site_settings_host_override.en.yml")

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

  # Test-only fixture loaded into a fresh Simple backend — never mutates
  # I18n.load_path. Visible flashes must not use an always-loaded host override.
  test "fresh-backend last-file-wins host fixture overrides gem english on save notice" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_SAVED

    sign_in @admin
    switch_root!(@studio_root)

    previous_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations
    I18n.t(SAVED_KEY)
    I18n.backend.load_translations(FRESH_HOST_LOCALE.to_s)

    assert_equal @load_path_before, I18n.load_path
    assert_equal HOST_SAVED, I18n.t(SAVED_KEY)

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
