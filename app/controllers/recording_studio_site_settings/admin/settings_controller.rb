# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Admin
    class SettingsController < ApplicationController
      before_action :authorize_site_settings_admin!
      before_action :require_site_root!

      def show
        assign_settings
      end

      def update
        authorize_site_settings_admin!(role: :admin)
        save_site_settings
        redirect_to settings_path, notice: "Saved. That's the name and logo for this site."
      rescue RecordingStudioSiteSettings::Unauthorized
        head :forbidden
      rescue ActiveRecord::RecordInvalid
        render_invalid_settings
      end

      private

      def authorize_site_settings_admin!(role: :view)
        context = recording_studio_admin_context
        require_admin_access!(context, role)
        RecordingStudioAdmin::BlastRadius.authorize!(
          RecordingStudioSiteSettings::Admin::SiteSettingsSection,
          context: context,
          label: "Site settings"
        )
      end

      def require_admin_access!(context, role)
        actor = context.current_actor
        recording = context.access_recording
        return if actor && recording && RecordingStudioAccessible.authorized?(actor:, recording:, role:)

        raise RecordingStudioAdmin::AuthorizationFailed, "You cannot change this site's name or logo."
      end

      def require_site_root!
        @site_root = RecordingStudioSiteSettings.site_root_for(recording_studio_admin_context)
        head :not_found if @site_root.blank?
      end

      def save_site_settings
        RecordingStudioSiteSettings.update!(
          @site_root,
          name: submitted_name,
          actor: current_actor,
          **submitted_logo
        )
      end

      def render_invalid_settings
        assign_settings
        @name = submitted_name
        flash.now[:alert] = "Check the name and try again."
        render :show, status: :unprocessable_entity
      end

      def assign_settings
        @name = RecordingStudioSiteSettings.name_for(@site_root)
        @logo = RecordingStudioSiteSettings.logo_for(@site_root)
      end

      def submitted_name
        settings_params[:name].to_s.strip
      end

      def submitted_logo
        logo = settings_params[:logo]
        return {} if logo.blank?

        { logo_io: logo.tempfile, filename: logo.original_filename, content_type: logo.content_type }
      end

      def settings_params
        params.fetch(:site_setting, {}).permit(:name, :logo)
      end
    end
  end
end
