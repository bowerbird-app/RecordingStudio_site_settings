# frozen_string_literal: true

require "cgi"
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
    recording = RecordingStudioSiteSettings.recording_for(@studio_root)
    image = RecordingStudioSiteSettings.logo_recording_for(@studio_root)

    sign_in @admin
    switch_root!(@studio_root)

    get recording_studio_site_settings.settings_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
    assert_select %(body[data-theme="rounded"]), count: 1
    assert_select "nav.flat-pack-page-nav", count: 1
    assert_select "h1", text: "Site name and logo", count: 1
    assert_includes response.body, 'value="Studio"'
    assert_includes response.body, "Cancel"
    assert_includes response.body, "md:grid-cols-2"
    refute_includes response.body, "flex w-full flex-col gap-6"
    refute_includes response.body, "No logo yet"
    refute_includes response.body, "Upload a file or drag and drop"
    refute_includes response.body, "FlatPack::FileInput"
    refute_includes response.body, "Choose File"
    refute_includes response.body, "parent-attachment-slot"
    assert_select "turbo-frame#site-logo"
    assert_select "#site-logo button", text: "Change"
    assert_select "input[type='file'].hidden"
    assert_includes response.body, "h-24 w-24"
    assert_includes response.body, "rounded-[var(--avatar-radius-square)]"
    refute_includes response.body, ">Avatar<"
    assert_includes unescaped_page, recording_studio_attachable.attachment_path(
      image,
      redirect_mode: "return_to",
      return_to: recording_studio_site_settings.settings_path
    )
    refute_includes response.body, recording_studio_attachable.recording_attachment_imports_path(recording)
  end

  test "an authorized actor sees an empty logo for a named site" do
    RecordingStudioSiteSettings.update!(@client_root, name: "Client Studio", actor: @admin)
    recording = RecordingStudioSiteSettings.recording_for(@client_root)

    sign_in @admin
    switch_root!(@client_root)

    get recording_studio_site_settings.settings_path

    assert_response :success
    assert_includes response.body, 'value="Client Studio"'
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
    assert_select "h1", text: "Site name and logo", count: 1
    refute_includes response.body, "No logo yet"
    refute_includes response.body, "Upload a file or drag and drop"
    refute_includes response.body, "Choose File"
    refute_includes response.body, "parent-attachment-slot"
    assert_select "turbo-frame#site-logo"
    assert_select "#site-logo button", text: "Add"
    assert_select "input[type='file'].hidden"
    assert_includes response.body, "h-24 w-24"
    assert_includes response.body, "M12 2C6.48 2 2 6.48"
    assert_includes unescaped_page, recording_studio_attachable.recording_attachment_imports_path(
      recording,
      redirect_mode: "return_to",
      return_to: recording_studio_site_settings.settings_path
    )
  end

  test "an authorized actor can update the site name" do
    RecordingStudioSiteSettings.update!(@studio_root, name: "Studio", actor: @admin)
    sign_in @admin
    switch_root!(@studio_root)

    patch recording_studio_site_settings.settings_path, params: {
      site_setting: { name: "North Studio" }
    }

    assert_redirected_to recording_studio_site_settings.settings_path
    follow_redirect!
    assert_includes unescaped_page, "Saved. That's the name and logo for this site."
    assert_equal "North Studio", RecordingStudioSiteSettings.name_for(@studio_root)
  end

  test "an authorized actor can attach a logo through Attachable" do
    RecordingStudioSiteSettings.update!(@studio_root, name: "Studio", actor: @admin)
    recording = RecordingStudioSiteSettings.recording_for(@studio_root)
    settings_path = recording_studio_site_settings.settings_path
    sign_in @admin
    switch_root!(@studio_root)

    assert_difference -> { recording.images.to_a.size }, +1 do
      post recording_studio_attachable.recording_attachment_imports_path(
        recording,
        redirect_mode: "return_to",
        return_to: settings_path
      ), params: {
        attachment_import: {
          attachments: [
            { file: Rack::Test::UploadedFile.new(TEST_LOGO_PATH.to_s, "image/png") }
          ]
        }
      }
    end

    assert_redirected_to settings_path
    assert RecordingStudioSiteSettings.logo_for(@studio_root).present?
  end

  private

  def unescaped_page
    CGI.unescapeHTML(response.body)
  end
end
