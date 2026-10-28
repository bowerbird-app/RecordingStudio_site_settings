# frozen_string_literal: true

require "test_helper"

class SiteSettingsControllerAuthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include AccessGrantTestHelper
  include SiteSettingsTestHelper

  setup do
    @admin = create_user("admin-controller-auth-#{SecureRandom.hex(4)}@example.com")
    @studio_root = workspace_root("Studio")
    @site_root = admin_root_recording
    grant_site_settings_admin!(@admin, workspace_root: @studio_root)
  end

  test "ApplicationController includes ControllerAuth with site_settings method names" do
    controller = RecordingStudioSiteSettings::ApplicationController

    assert_includes controller.ancestors, RecordingStudioAccessible::ControllerAuth
    assert controller.private_method_defined?(:authenticate_recording_studio_site_settings!)
    assert controller.private_method_defined?(:current_actor)
    assert controller.private_method_defined?(:set_current_actor)
    refute_includes controller._helper_methods.map(&:to_s), "current_site_settings_root"
    refute_includes RecordingStudioSiteSettings::Admin::SettingsController._helper_methods.map(&:to_s),
                    "current_site_settings_root"

    options = controller.recording_studio_auth_options
    assert options.fetch(:actor_resolver).respond_to?(:call)
    assert_equal :authenticate_recording_studio_site_settings!, options.fetch(:authenticate_method)
    assert_equal :current_actor, options.fetch(:actor_method)
    assert_equal :set_current_actor, options.fetch(:set_current_actor_method)
    assert_equal RecordingStudioAdmin.configuration, controller.recording_studio_auth_config_resolver.call
  end

  test "generated auth helpers stay out of action_methods" do
    methods = RecordingStudioSiteSettings::ApplicationController.action_methods

    refute_includes methods, "authenticate_recording_studio_site_settings!"
    refute_includes methods, "current_actor"
    refute_includes methods, "set_current_actor"
    refute_includes methods, "current_site_settings_root"
    refute_includes methods, "authorize_recording!"
    refute_includes methods, "require_root!"
  end

  test "verify_authenticity_token runs before ControllerAuth auth filters" do
    filters = RecordingStudioSiteSettings::ApplicationController
      ._process_action_callbacks
      .select { |callback| callback.kind == :before }
      .map(&:filter)

    csrf_at = filters.index(:verify_authenticity_token)
    auth_at = filters.index(:authenticate_recording_studio_site_settings!)
    actor_at = filters.index(:set_current_actor)

    assert csrf_at, "expected :verify_authenticity_token in before filters"
    assert auth_at, "expected :authenticate_recording_studio_site_settings! in before filters"
    assert actor_at, "expected :set_current_actor in before filters"
    assert csrf_at < auth_at, "CSRF must run before authenticate"
    assert csrf_at < actor_at, "CSRF must run before set_current_actor"
  end

  test "signed-out write with a bad CSRF token returns 422 instead of an auth redirect" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    patch recording_studio_site_settings.settings_path,
          params: {
            authenticity_token: "not-a-real-token",
            site_setting: { name: "CSRF should win" }
          }

    assert_response :unprocessable_entity
    refute_predicate response, :redirect?
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "settings screen redirects unauthenticated callers through Admin authentication_method" do
    get recording_studio_site_settings.settings_path

    assert_redirected_to new_user_session_path
  end

  test "settings screen assigns Current.actor from current_actor via ControllerAuth" do
    RecordingStudioSiteSettings.update!(@site_root, name: "Controller Auth Site", actor: @admin)
    sign_in @admin
    switch_root!(@studio_root)
    Current.reset if Current.respond_to?(:reset)

    get recording_studio_site_settings.settings_path

    assert_response :success

    patch recording_studio_site_settings.settings_path, params: { site_setting: { name: "Controller Auth Saved" } }

    assert_redirected_to recording_studio_site_settings.settings_path
    recording = RecordingStudioSiteSettings.recording_for(@site_root)
    assert recording.events(actions: "updated", actor: @admin).exists?
    assert_equal "Controller Auth Saved", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "current_actor falls back to Current.actor when current_actor_method is unset" do
    previous = RecordingStudioAdmin.configuration.current_actor_method
    RecordingStudioAdmin.configuration.current_actor_method = nil
    RecordingStudioSiteSettings.update!(@site_root, name: "Controller Auth Site", actor: @admin)
    sign_in @admin
    switch_root!(@studio_root)
    Current.reset if Current.respond_to?(:reset)

    get recording_studio_site_settings.settings_path

    assert_response :forbidden
  ensure
    RecordingStudioAdmin.configuration.current_actor_method = previous
    Current.actor = nil if defined?(Current)
  end

  test "settings screen still forbids actors without admin-root access" do
    member = create_user("member-controller-auth-#{SecureRandom.hex(4)}@example.com")
    sign_in member

    get recording_studio_site_settings.settings_path

    assert_response :forbidden
  end
end
