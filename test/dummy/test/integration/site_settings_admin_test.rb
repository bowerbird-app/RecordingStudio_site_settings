# frozen_string_literal: true

require "base64"
require "cgi"
require "digest"
require "test_helper"

class SiteSettingsAdminTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user("admin-settings-#{SecureRandom.hex(4)}@example.com")
    @member = create_user("member-settings-#{SecureRandom.hex(4)}@example.com")
    @studio_root = workspace_root("Studio")
    @client_root = workspace_root("Client Studio")
    @site_root = admin_root_recording
    @empty_root = empty_admin_root_recording
    grant_site_settings_admin!(@admin, workspace_root: @studio_root)
    bootstrap_owner_access!(@admin, @client_root)
    bootstrap_owner_access!(@admin, @empty_root)
  end

  test "an actor without admin-root access gets 403" do
    sign_in @member

    get recording_studio_site_settings.settings_path

    assert_response :forbidden
  end

  test "an authorized actor sees the attached square logo, wide logo, and empty favicon" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    File.open(TEST_SQUARE_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @site_root,
        name: "Studio",
        actor: @admin,
        square_logo_io: io,
        square_logo_filename: "square-logo.png",
        square_logo_content_type: "image/png"
      )
    end
    File.open(TEST_WIDE_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @site_root,
        name: "Studio",
        actor: @admin,
        wide_logo_io: io,
        wide_logo_filename: "wide-logo.png",
        wide_logo_content_type: "image/png"
      )
    end
    recording = RecordingStudioSiteSettings.recording_for(@site_root)
    square = RecordingStudioSiteSettings.square_logo_recording_for(@site_root)
    wide = RecordingStudioSiteSettings.wide_logo_recording_for(@site_root)

    sign_in @admin
    switch_root!(@studio_root)

    get recording_studio_site_settings.settings_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
    assert_select %(html[data-theme="rounded"]), count: 1
    assert_select "nav.flat-pack-page-nav", count: 1
    assert_match(/flat-pack--page-nav#back/, response.body)
    assert_select %(nav.flat-pack-page-nav [aria-label="Go back"]), count: 1
    assert_includes response.body, "p-[var(--button-icon-only-padding-md)]"
    assert_includes response.body, "w-5 h-5"
    assert_select "h1", text: "Site name and logos", count: 1
    assert_includes response.body, 'value="Studio"'
    assert_includes response.body, "Cancel"
    assert_includes response.body, "md:grid-cols-2"
    refute_includes response.body, "flex w-full flex-col gap-6"
    refute_includes response.body, "No logo yet"
    refute_includes response.body, "Upload a file or drag and drop"
    refute_includes response.body, "FlatPack::FileInput"
    refute_includes response.body, "Choose File"
    refute_includes response.body, "parent-attachment-slot"
    refute_includes response.body, "flat-pack-button-group"
    refute_includes response.body, "flat-pack-sidebar-layout"
    assert_select "aside", count: 0
    assert_select "header img", count: 0
    assert_select "form#site-name-form", count: 1
    assert_select %(button[form="site-name-form"]), text: "Save", count: 1
    body = response.body
    name_at = body.index("Site name")
    wide_at = body.index("Wide logo")
    square_at = body.index("Square logo")
    favicon_at = body.index(">Favicon<") || body.index("Favicon")
    save_at = body.index(">Save<")
    cancel_at = body.index(">Cancel<")
    assert name_at < wide_at, "Site name must render before Wide logo"
    assert wide_at < square_at, "Wide logo must render before Square logo"
    assert square_at < favicon_at, "Square logo must render before Favicon"
    assert favicon_at < save_at, "Favicon must render before Save"
    assert save_at < cancel_at, "Save must render before Cancel"
    assert_select "turbo-frame#site-square-logo"
    assert_select "turbo-frame#site-wide-logo"
    assert_select "turbo-frame#site-favicon"
    assert_select "#site-square-logo button", text: "Change"
    assert_select "#site-wide-logo button", text: "Change"
    assert_select "#site-favicon button", text: "Add"
    assert_select "input[type='file'].hidden"
    assert_includes response.body, "h-24 w-24"
    assert_includes response.body, "h-16 w-16"
    assert_includes response.body, "rounded-[var(--avatar-radius-square)]"
    assert_includes response.body, "Square logo"
    assert_includes response.body, "Wide logo"
    assert_includes response.body, "Favicon"
    assert_includes response.body, "Browser tab."
    refute_includes response.body, ">Avatar<"
    assert_includes unescaped_page, recording_studio_attachable.attachment_path(
      square,
      redirect_mode: "return_to",
      return_to: recording_studio_site_settings.settings_path
    )
    assert_includes unescaped_page, recording_studio_attachable.attachment_path(
      wide,
      redirect_mode: "return_to",
      return_to: recording_studio_site_settings.settings_path
    )
    assert_includes unescaped_page, recording_studio_attachable.recording_attachment_imports_path(
      recording,
      redirect_mode: "return_to",
      return_to: recording_studio_site_settings.settings_path
    )
    assert_includes response.body, 'name="attachment_import[attachments][][name]"'
    assert_includes response.body, 'value="favicon"'
    refute_includes frame_html("site-favicon"), "M12 2C6.48 2 2 6.48"
    assert_includes frame_html("site-favicon"), "flat-pack--icon-name-value=\"photo\""
    refute_includes frame_html("site-square-logo"), "M12 2C6.48 2 2 6.48"
    square_preview = RecordingStudioSiteSettings.square_logo_for(@site_root).preview_url
    wide_preview = RecordingStudioSiteSettings.wide_logo_for(@site_root).preview_url

    assert_includes response.body, square_preview
    assert_includes response.body, wide_preview
    refute_includes response.body, 'width="192"'
  end

  test "an authorized actor sees empty photo icons for a named site" do
    RecordingStudioSiteSettings.update!(@empty_root, name: "Client Studio", actor: @admin)
    recording = RecordingStudioSiteSettings.recording_for(@empty_root)

    sign_in @admin

    with_site_root(@empty_root) do
      get recording_studio_site_settings.settings_path

      assert_response :success
      assert_includes response.body, 'value="Client Studio"'
      assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
      assert_select "h1", text: "Site name and logos", count: 1
      refute_includes response.body, "No logo yet"
      refute_includes response.body, "Upload a file or drag and drop"
      refute_includes response.body, "Choose File"
      refute_includes response.body, "parent-attachment-slot"
      assert_select "turbo-frame#site-square-logo"
      assert_select "turbo-frame#site-wide-logo"
      assert_select "turbo-frame#site-favicon"
      assert_select "#site-square-logo button", text: "Add"
      assert_select "#site-wide-logo button", text: "Add"
      assert_select "#site-favicon button", text: "Add"
      assert_select "input[type='file'].hidden"
      assert_includes response.body, "h-24 w-24"
      assert_includes response.body, "h-16 w-16"
      refute_includes frame_html("site-square-logo"), "M12 2C6.48 2 2 6.48"
      refute_includes frame_html("site-wide-logo"), "M12 2C6.48 2 2 6.48"
      refute_includes frame_html("site-favicon"), "M12 2C6.48 2 2 6.48"
      assert_includes frame_html("site-square-logo"), "flat-pack--icon-name-value=\"photo\""
      assert_includes frame_html("site-wide-logo"), "flat-pack--icon-name-value=\"photo\""
      assert_includes frame_html("site-favicon"), "flat-pack--icon-name-value=\"photo\""
      assert_select "header img", count: 0
      assert_select "aside", count: 0
      assert_includes unescaped_page, recording_studio_attachable.recording_attachment_imports_path(
        recording,
        redirect_mode: "return_to",
        return_to: recording_studio_site_settings.settings_path
      )
      assert_includes response.body, 'value="square_logo"'
      assert_includes response.body, 'value="wide_logo"'
      assert_includes response.body, 'value="favicon"'
    end
  end

  test "an authorized actor can update the site name" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    sign_in @admin
    switch_root!(@studio_root)

    patch recording_studio_site_settings.settings_path, params: {
      site_setting: { name: "North Studio" }
    }

    assert_redirected_to recording_studio_site_settings.settings_path
    follow_redirect!
    assert_includes unescaped_page, "Saved. That's this site's name, logos, and tab icon."
    assert_equal "North Studio", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "blank site name re-renders with the check-name alert" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    sign_in @admin
    switch_root!(@studio_root)

    patch recording_studio_site_settings.settings_path, params: {
      site_setting: { name: "" }
    }

    assert_response :unprocessable_entity
    assert_equal "Check the name and try again.", flash[:alert]
    assert_includes unescaped_page, "Check the name and try again."
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "admin section title and edit link stay main English literals" do
    assert_equal "Site", RecordingStudioSiteSettings::Admin::SiteSettingsSection.title
    edit_text = RecordingStudioSiteSettings::Admin::SiteSettingsSection.links
                                                                       .find { |link| link.name == :edit }
                                                                       .text
    show_text = RecordingStudioSiteSettings::Admin::SiteSettingsResource.actions.fetch(:show).text

    assert_equal "Edit site settings", edit_text
    assert_equal "Site name and logos", show_text
    assert_equal "Save",
                 RecordingStudioSiteSettings::Admin::SiteSettingsResource.actions.fetch(:edit).text
    assert_equal "Name, logos, and the browser tab icon.",
                 RecordingStudioSiteSettings::Admin::SiteSettingsSection.subtitle
    assert_kind_of String, RecordingStudioSiteSettings::Admin::SiteSettingsSection.title
    assert_kind_of String, edit_text
    assert_kind_of String, show_text
  end

  test "french locale changes flash notice while English stays byte-identical" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    sign_in @admin
    switch_root!(@studio_root)

    previous_backend = I18n.backend
    previous_available = I18n.available_locales
    I18n.available_locales = Array(previous_available) | %i[en fr]
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        site_settings: {
          flashes: {
            saved: "Enregistré. Nom, logos et icône d'onglet."
          }
        }
      }
    )

    I18n.with_locale(:fr) do
      patch recording_studio_site_settings.settings_path, params: {
        site_setting: { name: "Studio FR" }
      }
      assert_redirected_to recording_studio_site_settings.settings_path
      follow_redirect!
      assert_includes unescaped_page, "Enregistré. Nom, logos et icône d'onglet."
    end

    I18n.with_locale(:en) do
      patch recording_studio_site_settings.settings_path, params: {
        site_setting: { name: "Studio EN" }
      }
      assert_redirected_to recording_studio_site_settings.settings_path
      follow_redirect!
      assert_includes unescaped_page, "Saved. That's this site's name, logos, and tab icon."
    end
  ensure
    I18n.available_locales = previous_available if previous_available
    I18n.backend = previous_backend if previous_backend
    I18n.reload!
  end

  test "an authorized actor can attach a square logo through Attachable" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    recording = RecordingStudioSiteSettings.recording_for(@site_root)
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
            { file: Rack::Test::UploadedFile.new(TEST_SQUARE_LOGO_PATH.to_s, "image/png"), name: "square_logo" }
          ]
        }
      }
    end

    assert_redirected_to settings_path
    assert RecordingStudioSiteSettings.square_logo_for(@site_root).present?
    assert_equal "square_logo", RecordingStudioSiteSettings.square_logo_recording_for(@site_root).recordable.name
  end

  test "an authorized actor can attach a wide logo without replacing the square logo" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    File.open(TEST_SQUARE_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @site_root,
        name: "Studio",
        actor: @admin,
        square_logo_io: io,
        square_logo_filename: "square-logo.png",
        square_logo_content_type: "image/png"
      )
    end
    recording = RecordingStudioSiteSettings.recording_for(@site_root)
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
            { file: Rack::Test::UploadedFile.new(TEST_WIDE_LOGO_PATH.to_s, "image/png"), name: "wide_logo" }
          ]
        }
      }
    end

    assert_redirected_to settings_path
    assert RecordingStudioSiteSettings.square_logo_for(@site_root).present?
    assert RecordingStudioSiteSettings.wide_logo_for(@site_root).present?
    assert_equal "square_logo", RecordingStudioSiteSettings.square_logo_recording_for(@site_root).recordable.name
    assert_equal "wide_logo", RecordingStudioSiteSettings.wide_logo_recording_for(@site_root).recordable.name
  end

  test "an authorized actor can attach a favicon without replacing a logo" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    File.open(TEST_SQUARE_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @site_root,
        name: "Studio",
        actor: @admin,
        square_logo_io: io,
        square_logo_filename: "square-logo.png",
        square_logo_content_type: "image/png"
      )
    end
    recording = RecordingStudioSiteSettings.recording_for(@site_root)
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
            { file: Rack::Test::UploadedFile.new(TEST_LOGO_PATH.to_s, "image/png"), name: "favicon" }
          ]
        }
      }
    end

    assert_redirected_to settings_path
    assert RecordingStudioSiteSettings.square_logo_for(@site_root).present?
    assert RecordingStudioSiteSettings.favicon_for(@site_root).present?
    assert_equal "square_logo", RecordingStudioSiteSettings.square_logo_recording_for(@site_root).recordable.name
    assert_equal "favicon", RecordingStudioSiteSettings.favicon_recording_for(@site_root).recordable.name
  end

  test "mark add and change use the site settings recording direct upload" do
    assert_not Rails.application.routes.named_routes.names.include?(:rails_direct_uploads)
    assert_equal false, ActiveStorage.draw_routes

    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    recording = RecordingStudioSiteSettings.recording_for(@site_root)
    settings_path = recording_studio_site_settings.settings_path
    upload_path = recording_studio_attachable.recording_direct_uploads_path(recording)
    sign_in @admin
    switch_root!(@studio_root)

    get settings_path

    assert_response :success
    assert_equal 3, response.body.scan(upload_path).size
    refute_includes response.body, "/rails/active_storage"

    signed_id = upload_bytes!("square-logo.png", TEST_SQUARE_LOGO_PATH)
    assert_equal recording.id.to_s, issued_blob(signed_id).metadata["parent_recording_id"]
    assert_equal 1, RecordingStudioAttachable::DirectUpload.pending_count(recording, @admin)

    post recording_studio_attachable.recording_attachment_imports_path(
      recording, redirect_mode: "return_to", return_to: settings_path
    ), params: {
      attachment_import: { attachments: [{ signed_blob_id: signed_id, name: "square_logo" }] }
    }

    assert_redirected_to settings_path
    square = RecordingStudioSiteSettings.square_logo_recording_for(@site_root)
    assert_equal "square-logo.png", square.recordable.original_filename
    assert_equal 0, RecordingStudioAttachable::DirectUpload.pending_count(recording, @admin)

    get settings_path

    square_frame = CGI.unescapeHTML(frame_html("site-square-logo"))
    assert_includes square_frame, %(direct-upload-url-value="#{upload_path}")
    assert_includes square_frame, recording_studio_attachable.attachment_path(
      square, redirect_mode: "return_to", return_to: settings_path
    )

    replacement_id = upload_bytes!("wide-logo.png", TEST_WIDE_LOGO_PATH)
    assert_equal 1, RecordingStudioAttachable::DirectUpload.pending_count(recording, @admin)
    patch recording_studio_attachable.attachment_path(
      square, redirect_mode: "return_to", return_to: settings_path
    ), params: { attachment: { signed_blob_id: replacement_id } }

    assert_redirected_to settings_path
    assert_equal square.id, RecordingStudioSiteSettings.square_logo_recording_for(@site_root).id
    assert_equal "wide-logo.png", RecordingStudioSiteSettings.square_logo_recording_for(@site_root).recordable.original_filename
    assert_equal 0, RecordingStudioAttachable::DirectUpload.pending_count(recording, @admin)

    forged = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "forged.png", byte_size: 1, checksum: file_checksum("x"), content_type: "image/png"
    )
    patch recording_studio_attachable.attachment_path(
      square, redirect_mode: "return_to", return_to: settings_path
    ), params: { attachment: { signed_blob_id: forged.signed_id } }

    assert_redirected_to settings_path
    assert_equal "mismatched purpose", flash[:alert]
    assert_equal "wide-logo.png", RecordingStudioSiteSettings.square_logo_recording_for(@site_root).recordable.original_filename
    assert_equal 0, RecordingStudioAttachable::DirectUpload.pending_count(recording, @admin)
  end

  test "the dummy layout prints a favicon link when a tab icon is attached" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    File.open(TEST_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @site_root,
        name: "Studio",
        actor: @admin,
        favicon_io: io,
        favicon_filename: "favicon.png",
        favicon_content_type: "image/png"
      )
    end
    preview = RecordingStudioSiteSettings.favicon_for(@site_root).preview_url

    sign_in @admin
    switch_root!(@studio_root)

    get root_path

    assert_response :success
    assert_select %(link[rel="icon"][href="#{preview}"])
  end

  test "dummy home prints the wide logo in a sidebar and settings does not" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @admin)
    File.open(TEST_WIDE_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @site_root,
        name: "Studio",
        actor: @admin,
        wide_logo_io: io,
        wide_logo_filename: "wide-logo.png",
        wide_logo_content_type: "image/png"
      )
    end
    preview = RecordingStudioSiteSettings.wide_logo_for(@site_root).preview_url

    sign_in @admin
    switch_root!(@client_root)

    get "/"

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
    refute_includes response.body, "flat-pack-sidebar-layout"
    assert_select "aside img[src=?]", preview
    assert_select "aside img[width='192']"
    refute_includes response.body, "Site name and logos"

    get "/docs/install"

    assert_response :success
    assert_select "aside img[src=?]", preview
    refute_includes response.body, "flat-pack-sidebar-layout"

    get recording_studio_site_settings.settings_path

    assert_response :success
    assert_select "aside", count: 0
    assert_select "header img", count: 0
    refute_includes response.body, 'width="192"'
    assert_includes response.body, preview
  end

  private

  def unescaped_page
    CGI.unescapeHTML(response.body)
  end

  def upload_bytes!(filename, path)
    bytes = File.binread(path)
    post recording_studio_attachable.recording_direct_uploads_path(
      RecordingStudioSiteSettings.recording_for(@site_root)
    ), params: {
      blob: {
        filename: filename,
        byte_size: bytes.bytesize,
        checksum: file_checksum(bytes),
        content_type: "image/png"
      }
    }, as: :json
    assert_response :success, response.body
    ticket = response.parsed_body
    put_direct_upload(ticket, bytes)
    ticket.fetch("signed_id")
  end

  def put_direct_upload(ticket, bytes)
    uri = URI(ticket.dig("direct_upload", "url"))
    put "#{uri.path}?#{uri.query}", params: bytes, headers: ticket.dig("direct_upload", "headers")
    assert_response :no_content, response.body
  end

  def file_checksum(bytes)
    Base64.strict_encode64(Digest::MD5.digest(bytes))
  end

  def issued_blob(signed_id)
    ActiveStorage::Blob.find_signed!(signed_id, purpose: RecordingStudioAttachable::DirectUpload::PURPOSE)
  end

  def frame_html(id)
    css_select("turbo-frame##{id}").first.to_html
  end
end
