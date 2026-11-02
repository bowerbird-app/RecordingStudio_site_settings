# frozen_string_literal: true

module RecordingStudioSiteSettings
  class ApplicationController < ActionController::Base
    include Devise::Controllers::Helpers if defined?(Devise::Controllers::Helpers)

    if defined?(RecordingStudio::RootSwitchable::ControllerSupport)
      include RecordingStudio::RootSwitchable::ControllerSupport
    end

    protect_from_forgery with: :exception
    recording_studio_layout
    helper RecordingStudioAttachable::ApplicationHelper if defined?(RecordingStudioAttachable::ApplicationHelper)
    include Rails.application.routes.mounted_helpers

    helper Rails.application.routes.mounted_helpers

    helper_method :recording_studio_admin_context

    rescue_from RecordingStudioAdmin::AuthorizationFailed, with: :render_forbidden
    rescue_from RecordingStudioAdmin::DefinitionNotFound, with: :render_forbidden
    rescue_from RecordingStudioSiteSettings::Unauthorized, with: :render_forbidden

    # After protect_from_forgery so :verify_authenticity_token stays ahead of auth /
    # set-actor filters (same order as main's before_action list).
    include RecordingStudioAccessible::ControllerAuth

    recording_studio_auth(
      config: -> { RecordingStudioAdmin.configuration },
      prefix: :site_settings,
      authenticate_method: :authenticate_recording_studio_site_settings!,
      set_current_actor_method: :set_current_actor,
      actor_method: :current_actor,
      actor_resolver: lambda {
        method_name = RecordingStudioAdmin.configuration.current_actor_method
        next send(method_name) if method_name && respond_to?(method_name, true)

        Current.actor if defined?(Current)
      }
    )
    _helpers.send(:remove_method, :current_site_settings_root)
    self._helper_methods -= [:current_site_settings_root]

    private

    def recording_studio_admin_context
      @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
        params: params.to_unsafe_h,
        current_actor: current_actor,
        controller: self,
        routes: main_app,
        view_context: view_context
      )
    end

    def render_forbidden
      head :forbidden
    end
  end
end
