# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "devise/test/integration_helpers"

module AccessGrantTestHelper
  def bootstrap_owner_access!(actor, recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    return result.value if result.success?

    manager = access_manager_for(actor)
    if manager && already_bootstrapped?(result)
      result = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: actor,
        role: :admin,
        manager_actor: manager
      )
    end

    raise result.error if result.failure?

    result.value
  end

  def already_bootstrapped?(result)
    result.error.to_s.include?(
      RecordingStudioAccessible::Services::BootstrapOwnerAccess::ALREADY_BOOTSTRAPPED_MESSAGE
    )
  end

  def access_manager_for(actor)
    manager = User.find_by(email: "admin@admin.com")
    return manager if manager && manager.id != actor.id

    User.where.not(id: actor.id).first
  end

  def create_user(email)
    User.create!(email: email, password: "Password123!", password_confirmation: "Password123!")
  end
end

module SiteSettingsTestHelper
  TEST_LOGO_PATH = Rails.root.join("test/fixtures/files/logo.png")

  def admin_root_recording
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
  end

  def workspace_root(name)
    workspace = Workspace.find_or_create_by!(name: name)
    RecordingStudio.root_recording_for(workspace)
  end

  def grant_site_settings_admin!(actor, workspace_root: nil)
    bootstrap_owner_access!(actor, admin_root_recording)
    bootstrap_owner_access!(actor, workspace_root) if workspace_root
  end

  def switch_root!(root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: recording_studio_site_settings.settings_path
      }
    }
  end

  def upload_logo_io
    File.open(TEST_LOGO_PATH, "rb")
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include AccessGrantTestHelper
  include SiteSettingsTestHelper
end

class ActiveSupport::TestCase
  include AccessGrantTestHelper
  include SiteSettingsTestHelper
end
