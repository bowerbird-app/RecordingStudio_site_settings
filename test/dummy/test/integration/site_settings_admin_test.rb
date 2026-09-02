# frozen_string_literal: true

require "test_helper"

class SiteSettingsAdminTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user("admin-settings-#{SecureRandom.hex(4)}@example.com")
    @member = create_user("member-settings-#{SecureRandom.hex(4)}@example.com")
    @studio_root = workspace_root("Studio")
    @client_root = workspace_root("Client Studio")
    grant_site_settings_admin!(@admin, workspace_root: @studio_root)
    bootstrap_owner_access!(@admin, @client_root)
  end

  test "an actor without admin-root access gets 403" do
    sign_in @member

    get recording_studio_site_settings.settings_path

    assert_response :forbidden
  end

  test "an authorized actor sees the seeded name and logo" do
    RecordingStudioSiteSettings.update!(@studio_root, name: "Studio", actor: @admin)
    File.open(TEST_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @studio_root,
        name: "Studio",
        actor: @admin,
        logo_io: io,
        filename: "logo.png",
        content_type: "image/png"
      )
    end

    sign_in @admin
    switch_root!(@studio_root)

    get recording_studio_site_settings.settings_path

    assert_response :success
    assert_includes response.body, "Site name and logo"
    assert_select "h1", text: "Site name and logo", count: 1
    assert_includes response.body, 'value="Studio"'
    assert_includes response.body, "Cancel"
    refute_includes response.body, "flex w-full flex-col gap-6"
    refute_includes response.body, "No logo yet"
    assert_includes response.body, "/recording_studio_attachable/attachments/"
  end

  test "an authorized actor sees an empty logo for a named site" do
    RecordingStudioSiteSettings.update!(@client_root, name: "Client Studio", actor: @admin)

    sign_in @admin
    switch_root!(@client_root)

    get recording_studio_site_settings.settings_path

    assert_response :success
    assert_includes response.body, 'value="Client Studio"'
    assert_includes response.body, "No logo yet"
  end

  test "an authorized actor can update the site name" do
    RecordingStudioSiteSettings.update!(@studio_root, name: "Studio", actor: @admin)
    sign_in @admin
    switch_root!(@studio_root)

    patch recording_studio_site_settings.settings_path, params: {
      site_setting: { name: "North Studio" }
    }

    assert_redirected_to recording_studio_site_settings.settings_path
    assert_equal "North Studio", RecordingStudioSiteSettings.name_for(@studio_root)
  end

  test "an authorized actor can attach a logo from the admin form" do
    RecordingStudioSiteSettings.update!(@studio_root, name: "Studio", actor: @admin)
    sign_in @admin
    switch_root!(@studio_root)

    patch recording_studio_site_settings.settings_path, params: {
      site_setting: {
        name: "Studio",
        logo: Rack::Test::UploadedFile.new(TEST_LOGO_PATH.to_s, "image/png")
      }
    }

    assert_redirected_to recording_studio_site_settings.settings_path
    assert RecordingStudioSiteSettings.logo_for(@studio_root).present?
  end
end
