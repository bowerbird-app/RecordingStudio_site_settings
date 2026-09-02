# frozen_string_literal: true

require "test_helper"

class SiteSettingsStoreTest < ActiveSupport::TestCase
  setup do
    @actor = create_user("store-#{SecureRandom.hex(4)}@example.com")
    @root = workspace_root("Store #{SecureRandom.hex(4)}")
    bootstrap_owner_access!(@actor, @root)
  end

  test "name and logo persist on this gem's recording, not on the workspace" do
    RecordingStudioSiteSettings.update!(@root, name: "Harbor", actor: @actor)
    File.open(TEST_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @root,
        name: "Harbor",
        actor: @actor,
        logo_io: io,
        filename: "logo.png",
        content_type: "image/png"
      )
    end

    assert_equal "Harbor", RecordingStudioSiteSettings.name_for(@root)
    assert RecordingStudioSiteSettings.logo_for(@root).present?
    assert_equal "logo.png", RecordingStudioSiteSettings.logo_for(@root).filename
    assert_match(%r{/recording_studio_attachable/attachments/.+/preview/square_med},
                 RecordingStudioSiteSettings.logo_for(@root).preview_url.to_s)

    workspace = @root.recordable
    refute workspace.class.column_names.include?("logo")
    refute RecordingStudio.capability_enabled?(:attachable, for: Workspace)
    assert_equal 1, RecordingStudio::Recording.where(
      root_recording: @root,
      parent_recording: @root,
      recordable_type: "RecordingStudioSiteSettings::SiteSetting",
      trashed_at: nil
    ).count
    assert RecordingStudioSiteSettings.favicon_for(@root).blank?
  end

  test "a second update revises the name and keeps one settings recording" do
    RecordingStudioSiteSettings.update!(@root, name: "Harbor", actor: @actor)
    RecordingStudioSiteSettings.update!(@root, name: "Beacon", actor: @actor)

    recording = RecordingStudioSiteSettings.recording_for(@root)
    assert_equal "Beacon", RecordingStudioSiteSettings.name_for(@root)
    assert_equal 1, RecordingStudio::Recording.where(
      root_recording: @root,
      recordable_type: "RecordingStudioSiteSettings::SiteSetting",
      trashed_at: nil
    ).count
    assert recording.events(actions: "updated").exists?
  end

  test "an actor without edit access cannot write" do
    stranger = create_user("store-denied-#{SecureRandom.hex(4)}@example.com")

    error = assert_raises(RecordingStudioSiteSettings::Unauthorized) do
      RecordingStudioSiteSettings.update!(@root, name: "Nope", actor: stranger)
    end

    assert_equal "You cannot change this site's name, logo, or tab icon.", error.message
    assert_nil RecordingStudioSiteSettings.name_for(@root)
  end

  test "logo stays empty until a file is attached" do
    RecordingStudioSiteSettings.update!(@root, name: "Quiet Harbor", actor: @actor)

    logo = RecordingStudioSiteSettings.logo_for(@root)
    assert_equal "Quiet Harbor", RecordingStudioSiteSettings.name_for(@root)
    assert logo.blank?
    refute logo.present?
    assert RecordingStudioSiteSettings.favicon_for(@root).blank?
  end

  test "favicon stays a second named child and does not replace the logo" do
    RecordingStudioSiteSettings.update!(@root, name: "Harbor", actor: @actor)
    File.open(TEST_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @root,
        name: "Harbor",
        actor: @actor,
        logo_io: io,
        filename: "logo.png",
        content_type: "image/png"
      )
    end
    File.open(TEST_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @root,
        name: "Harbor",
        actor: @actor,
        favicon_io: io,
        favicon_filename: "favicon.png",
        favicon_content_type: "image/png"
      )
    end

    logo = RecordingStudioSiteSettings.logo_for(@root)
    favicon = RecordingStudioSiteSettings.favicon_for(@root)
    parent = RecordingStudioSiteSettings.recording_for(@root)

    assert logo.present?
    assert favicon.present?
    refute_equal logo.recording.id, favicon.recording.id
    assert_equal "logo", logo.recording.recordable.name
    assert_equal "favicon", favicon.recording.recordable.name
    assert_equal 2, parent.images(per_page: 24).size
    assert_match(%r{/recording_studio_attachable/attachments/.+/preview/square_small},
                 favicon.preview_url.to_s)
  end

  test "a favicon alone does not become the logo" do
    RecordingStudioSiteSettings.update!(@root, name: "Quiet Harbor", actor: @actor)
    File.open(TEST_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @root,
        name: "Quiet Harbor",
        actor: @actor,
        favicon_io: io,
        favicon_filename: "favicon.png",
        favicon_content_type: "image/png"
      )
    end

    assert RecordingStudioSiteSettings.logo_for(@root).blank?
    assert RecordingStudioSiteSettings.favicon_for(@root).present?
  end

  test "a legacy filename logo still counts as the logo" do
    RecordingStudioSiteSettings.update!(@root, name: "Harbor", actor: @actor)
    parent = RecordingStudioSiteSettings.recording_for(@root)
    File.open(TEST_LOGO_PATH, "rb") do |io|
      result = RecordingStudioAttachable::Services::ImportAttachment.call(
        parent_recording: parent,
        io: io,
        filename: "studio-logo.png",
        content_type: "image/png",
        actor: @actor
      )
      raise result.error if result.failure?
    end

    logo = RecordingStudioSiteSettings.logo_for(@root)
    assert logo.present?
    assert_equal "studio-logo", logo.recording.recordable.name
    assert RecordingStudioSiteSettings.favicon_for(@root).blank?

    File.open(TEST_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        @root,
        name: "Harbor",
        actor: @actor,
        favicon_io: io,
        favicon_filename: "favicon.png",
        favicon_content_type: "image/png"
      )
    end

    assert_equal "studio-logo", RecordingStudioSiteSettings.logo_for(@root).recording.recordable.name
    assert RecordingStudioSiteSettings.favicon_for(@root).present?
    refute_equal(
      RecordingStudioSiteSettings.logo_recording_for(@root).id,
      RecordingStudioSiteSettings.favicon_recording_for(@root).id
    )
  end
end
