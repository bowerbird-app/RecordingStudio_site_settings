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
    assert_equal ["Workspace"], RecordingStudio.allowed_parent_types_for("RecordingStudioSiteSettings::SiteSetting")
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

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil client_root_recording.parent_recording_id
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    assert_equal 2, Workspace.where(name: %w[Studio Client\ Studio]).count
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(root_recording)
    assert RecordingStudioSiteSettings.logo_for(root_recording).present?
    assert_equal "Client Studio", RecordingStudioSiteSettings.name_for(client_root_recording)
    assert RecordingStudioSiteSettings.logo_for(client_root_recording).blank?

    assert_no_difference -> { User.count } do
      load Rails.root.join("db/seeds.rb").to_s
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end

  test "workspace opts into accessible without attachable, and site settings owns the logo" do
    workspace_source = File.read(Rails.root.join("app/models/workspace.rb"))
    settings_source = File.read(RecordingStudioSiteSettings::Engine.root.join("app/models/recording_studio_site_settings/site_setting.rb"))

    refute_includes workspace_source, "Attachable"
    assert_includes settings_source, "Capabilities::Attachable"

    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
    refute RecordingStudio.capability_enabled?(:attachable, for: Workspace)
    assert RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioSiteSettings::SiteSetting)
    refute RecordingStudio.capability_enabled?(:accessible, for: Folder)
    refute RecordingStudio.capability_enabled?(:accessible, for: Page)
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end
end
