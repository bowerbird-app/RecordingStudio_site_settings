# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    # Mirrors Admin::SettingsController#authorize_site_settings_admin! without a controller:
    # the actor needs the role on the access recording, and the Site section's :site blast
    # radius only passes when that recording is the site admin recording.
    module Access
      DENIED_MESSAGE = "API access grant is not authorized for site settings"

      module_function

      def read(context)
        site_root_for!(context, :view)
      end

      def write(context)
        site_root_for!(context, :admin)
      end

      def actor_for(context)
        context&.access_grant&.actor
      end

      def site_root_for!(context, role)
        admin_context = admin_context_for(actor_for(context))
        deny! unless site_admin?(admin_context, role)

        root = RecordingStudioSiteSettings.site_root_for(admin_context)
        raise RecordingStudioApi::NotFoundError, "Site root was not found" if root.blank?

        root
      end

      def admin_context_for(actor)
        RecordingStudioAdmin::Context.new(params: {}, current_actor: actor, controller: nil)
      end

      def site_admin?(admin_context, role)
        actor = admin_context.current_actor
        recording = admin_context.access_recording
        return false if actor.blank? || recording.blank?
        return false unless RecordingStudioAccessible.authorized?(actor:, recording:, role:)

        RecordingStudioAdmin::BlastRadius.allowed?(
          RecordingStudioSiteSettings::Admin::SiteSettingsSection,
          context: admin_context
        )
      end

      def deny!
        raise RecordingStudioApi::AuthorizationError, DENIED_MESSAGE
      end
    end
  end
end
