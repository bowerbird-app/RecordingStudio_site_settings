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
    assert controller.private_method_defined?(:current_site_settings_root)
    assert_includes controller._helper_methods.map(&:to_s), "current_site_settings_root"

    options = controller.recording_studio_auth_options
    assert_equal :configured_as_is, options.fetch(:actor_resolution)
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

    assigned = nil
    RecordingStudioSiteSettings::ApplicationController.class_eval do
      alias_method :__original_set_current_actor_for_test, :set_current_actor

      define_method(:set_current_actor) do
        __original_set_current_actor_for_test
        Thread.current[:site_settings_controller_auth_actor] = Current.actor
      end
      private :set_current_actor
    end

    get recording_studio_site_settings.settings_path

    assigned = Thread.current[:site_settings_controller_auth_actor]
    assert_response :success
    assert_equal @admin, assigned
  ensure
    Thread.current[:site_settings_controller_auth_actor] = nil
    RecordingStudioSiteSettings::ApplicationController.class_eval do
      if private_method_defined?(:__original_set_current_actor_for_test) ||
         method_defined?(:__original_set_current_actor_for_test)
        alias_method :set_current_actor, :__original_set_current_actor_for_test
        remove_method :__original_set_current_actor_for_test
        private :set_current_actor
      end
    end
  end

  test "configured_as_is keeps a nil current_actor without falling back to Current.actor" do
    sign_in @admin
    switch_root!(@studio_root)
    Current.actor = @admin

    controller = RecordingStudioSiteSettings::Admin::SettingsController.new
    controller.define_singleton_method(:current_user) { nil }

    assert_nil controller.send(:current_actor)
  ensure
    Current.actor = nil if defined?(Current)
  end

  test "settings screen still forbids actors without admin-root access" do
    member = create_user("member-controller-auth-#{SecureRandom.hex(4)}@example.com")
    sign_in member

    get recording_studio_site_settings.settings_path

    assert_response :forbidden
  end
end
