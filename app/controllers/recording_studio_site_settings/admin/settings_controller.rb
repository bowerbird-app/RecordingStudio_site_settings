# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Admin
    class SettingsController < ApplicationController
      before_action :authorize_site_settings_admin!
      before_action :require_site_root!

      def show
        @name = RecordingStudioSiteSettings.name_for(@site_root)
        @logo = RecordingStudioSiteSettings.logo_for(@site_root)
      end

      def update
        name = settings_params[:name].to_s.strip
        logo = settings_params[:logo]

        authorize_site_settings_admin!(role: :admin)
        RecordingStudioSiteSettings.update!(
          @site_root,
          name: name,
          actor: current_actor,
          logo_io: logo.presence && logo.tempfile,
          filename: logo.presence && logo.original_filename,
          content_type: logo.presence && logo.content_type
        )

        redirect_to settings_path, notice: "Saved. That's the name and logo for this site."
      rescue RecordingStudioSiteSettings::Unauthorized
        head :forbidden
      rescue ActiveRecord::RecordInvalid
        @name = name
        @logo = RecordingStudioSiteSettings.logo_for(@site_root)
        flash.now[:alert] = "Check the name and try again."
        render :show, status: :unprocessable_entity
      end

      private

      def authorize_site_settings_admin!(role: :view)
        context = recording_studio_admin_context
        actor = context.current_actor
        recording = context.access_recording
        unless actor && recording
          raise RecordingStudioAdmin::AuthorizationFailed, "Site settings admin access is not configured"
        end

        unless RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)
          raise RecordingStudioAdmin::AuthorizationFailed, "You cannot change this site's name or logo."
        end

        RecordingStudioAdmin::BlastRadius.authorize!(
          RecordingStudioSiteSettings::Admin::SiteSettingsSection,
          context: context,
          label: "Site settings"
        )
      end

      def require_site_root!
        @site_root = RecordingStudioSiteSettings.site_root_for(recording_studio_admin_context)
        return if @site_root.present?

        head :not_found
      end

      def settings_params
        params.fetch(:site_setting, {}).permit(:name, :logo)
      end
    end
  end
end
