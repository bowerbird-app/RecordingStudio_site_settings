# frozen_string_literal: true

require "test_helper"

class RecordingStudioSiteSettingsHostTest < ActiveSupport::TestCase
  test "dummy app loads root switchable config and controller support" do
    assert_equal ["all_workspaces"], RecordingStudioRootSwitchable.configuration.scopes.keys
    assert_equal :application_layout, RecordingStudioRootSwitchable.configuration.layout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end

  test "dummy app validates recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_includes RecordingStudio.root_recordable_types, "Workspace"
    assert_includes RecordingStudio.root_recordable_types, "AdminRoot"
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for("Page")
    assert_equal ["AdminRoot"], RecordingStudioSiteSettings.configuration.site_root_types
    assert_equal ["AdminRoot"], RecordingStudio.allowed_parent_types_for("RecordingStudioSiteSettings::SiteSetting")
  end

  test "dummy app schema keeps accessible grants and site settings" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    assert connection.table_exists?(:recording_studio_site_settings)
    assert connection.table_exists?(:recording_studio_attachable_attachments)
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "dummy seeds use hierarchy idempotently and restore current actor" do
    Current.actor = nil

    load Rails.root.join("db/seeds.rb").to_s

    workspace = Workspace.find_by!(name: "Studio")
    client_workspace = Workspace.find_by!(name: "Client Studio")
    folder = Folder.find_by!(name: "Product Docs")
    page = Page.find_by!(title: "Getting Started")
    root_recording = RecordingStudio::Recording.find_by!(recordable: workspace)
    client_root_recording = RecordingStudio::Recording.find_by!(recordable: client_workspace)
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder)
    page_recording = RecordingStudio::Recording.find_by!(recordable: page)
    admin_root = AdminRoot.find_by!(name: "Admin")
    empty_admin = AdminRoot.find_by!(name: "Empty Admin")
    admin_root_recording = RecordingStudio::Recording.find_by!(recordable: admin_root)
    empty_admin_recording = RecordingStudio::Recording.find_by!(recordable: empty_admin)
    settings = RecordingStudioSiteSettings.recording_for(admin_root_recording)

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil client_root_recording.parent_recording_id
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    assert_equal 2, Workspace.where(name: %w[Studio Client\ Studio]).count
    assert_equal admin_root_recording.id, settings.parent_recording_id
    assert_equal admin_root_recording.id, settings.root_recording_id
    assert_nil RecordingStudioSiteSettings.recording_for(root_recording)
    assert_nil RecordingStudioSiteSettings.recording_for(client_root_recording)
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(admin_root_recording)
    assert RecordingStudioSiteSettings.square_logo_for(admin_root_recording).present?
    assert RecordingStudioSiteSettings.wide_logo_for(admin_root_recording).present?
    assert RecordingStudioSiteSettings.favicon_for(admin_root_recording).blank?
    assert_equal "Client Studio", RecordingStudioSiteSettings.name_for(empty_admin_recording)
    assert RecordingStudioSiteSettings.square_logo_for(empty_admin_recording).blank?
    assert RecordingStudioSiteSettings.wide_logo_for(empty_admin_recording).blank?
    assert RecordingStudioSiteSettings.favicon_for(empty_admin_recording).blank?

    assert_no_difference -> { User.count } do
      load Rails.root.join("db/seeds.rb").to_s
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end

  test "workspace opts into accessible without attachable, and site settings owns the logos" do
    workspace_source = File.read(Rails.root.join("app/models/workspace.rb"))
    settings_source = File.read(RecordingStudioSiteSettings::Engine.root.join("app/models/recording_studio_site_settings/site_setting.rb"))

    refute_includes workspace_source, "Attachable"
    assert_includes settings_source, "Capabilities::Attachable"
    assert_includes settings_source, "max_file_count: 3"

    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
    refute RecordingStudio.capability_enabled?(:attachable, for: Workspace)
    assert RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioSiteSettings::SiteSetting)
    refute RecordingStudio.capability_enabled?(:accessible, for: Folder)
    refute RecordingStudio.capability_enabled?(:accessible, for: Page)
    refute RecordingStudio.capability_enabled?(:accessible, for: RecordingStudioSiteSettings::SiteSetting)
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
    refute File.exist?(Rails.root.join("config/recording_studio_site_settings.yml"))
  end
end
