# frozen_string_literal: true

require "test_helper"

class SiteSettingsParentTest < ActiveSupport::TestCase
  setup do
    @owner = create_user("parent-owner-#{SecureRandom.hex(4)}@example.com")
    @member = create_user("parent-member-#{SecureRandom.hex(4)}@example.com")
    @admin_root = admin_root_recording("Parent Admin #{SecureRandom.hex(4)}")
    @workspace_root = workspace_root("Parent Workspace #{SecureRandom.hex(4)}")
    bootstrap_owner_access!(@owner, @admin_root)
    bootstrap_owner_access!(@owner, @workspace_root)
    bootstrap_owner_access!(@member, @workspace_root)
  end

  test "site settings may be recorded under AdminRoot and not under Workspace" do
    assert_equal ["AdminRoot"], RecordingStudio.allowed_parent_types_for(RecordingStudioSiteSettings::SiteSetting)
    assert RecordingStudio.parent_allowed?(
      child_type: RecordingStudioSiteSettings::SiteSetting,
      parent_recording: @admin_root
    )
    refute RecordingStudio.parent_allowed?(
      child_type: RecordingStudioSiteSettings::SiteSetting,
      parent_recording: @workspace_root
    )

    allowed = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioSiteSettings::SiteSetting.new(name: "Harbor"),
      root_recording: @admin_root,
      parent_recording: @admin_root
    ).recording

    assert_equal @admin_root.id, allowed.parent_recording_id
    assert_equal @admin_root.id, allowed.root_recording_id

    error = assert_raises(RecordingStudio::InvalidParent) do
      RecordingStudio.record!(
        action: "created",
        recordable: RecordingStudioSiteSettings::SiteSetting.new(name: "Nope"),
        root_recording: @workspace_root,
        parent_recording: @workspace_root
      )
    end
    assert_match(/cannot be recorded under Workspace/, error.message)
  end

  test "update is authorized from an AdminRoot grant and not from a Workspace grant" do
    RecordingStudioSiteSettings.update!(@admin_root, name: "Harbor", actor: @owner)
    settings = RecordingStudioSiteSettings.recording_for(@admin_root)

    refute RecordingStudio.capability_enabled?(:accessible, for: RecordingStudioSiteSettings::SiteSetting)
    assert RecordingStudioAccessible.authorized?(actor: @owner, recording: @admin_root, role: :edit)
    assert RecordingStudioAccessible.authorized?(actor: @owner, recording: settings, role: :edit)
    refute RecordingStudioAccessible.authorized?(actor: @member, recording: @admin_root, role: :edit)
    refute RecordingStudioAccessible.authorized?(actor: @member, recording: settings, role: :edit)

    error = assert_raises(RecordingStudioSiteSettings::Unauthorized) do
      RecordingStudioSiteSettings.update!(@admin_root, name: "Nope", actor: @member)
    end
    assert_equal "You cannot change this site's name, logos, or tab icon.", error.message
    assert_equal "Harbor", RecordingStudioSiteSettings.name_for(@admin_root)

    RecordingStudioSiteSettings.update!(@admin_root, name: "Beacon", actor: @owner)
    assert_equal "Beacon", RecordingStudioSiteSettings.name_for(@admin_root)
  end

  test "allowed parent types follow live site_root_types" do
    original = RecordingStudioSiteSettings.configuration.site_root_types.dup

    RecordingStudioSiteSettings.configuration.site_root_types = ["Workspace"]
    assert_equal ["Workspace"], RecordingStudio.allowed_parent_types_for(RecordingStudioSiteSettings::SiteSetting)
    assert RecordingStudio.parent_allowed?(
      child_type: RecordingStudioSiteSettings::SiteSetting,
      parent_recording: @workspace_root
    )
    refute RecordingStudio.parent_allowed?(
      child_type: RecordingStudioSiteSettings::SiteSetting,
      parent_recording: @admin_root
    )

    RecordingStudioSiteSettings.configuration.site_root_types = ["AdminRoot"]
    assert_equal ["AdminRoot"], RecordingStudio.allowed_parent_types_for(RecordingStudioSiteSettings::SiteSetting)
    assert RecordingStudio.parent_allowed?(
      child_type: RecordingStudioSiteSettings::SiteSetting,
      parent_recording: @admin_root
    )
    refute RecordingStudio.parent_allowed?(
      child_type: RecordingStudioSiteSettings::SiteSetting,
      parent_recording: @workspace_root
    )
  ensure
    RecordingStudioSiteSettings.configuration.site_root_types = original
  end
end
