# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    # Short-lived, session-free preview URL for a mark, for API clients such as ChatGPT. Uses Active Storage's
    # own redirect routes with an expiring signed blob id, so the URL is tamper-proof and stops working after
    # configuration.preview_url_expires_in. The Attachable preview route (session + access checks) is unchanged
    # and still used by the Site screen.
    module PreviewUrl
      module_function

      # Path (no host) or nil when the mark has nothing to preview.
      def path_for(logo, variant)
        target = preview_target(logo, variant)
        target && route_for(target)
      rescue StandardError
        nil
      end

      def route_for(target)
        blob = target.respond_to?(:blob) ? target.blob : target
        signed_id = blob.signed_id(expires_in: RecordingStudioSiteSettings.configuration.preview_url_expires_in)
        routes = Rails.application.routes.url_helpers
        return routes.rails_service_blob_path(signed_id, blob.filename) unless target.respond_to?(:variation)

        routes.rails_blob_representation_path(signed_id, target.variation.key, blob.filename)
      end

      def preview_target(logo, variant)
        attachment = logo&.recording&.recordable
        return unless attachment.respond_to?(:preview_target_named)

        target = attachment.preview_target_named(variant)
        return if target.nil? || (target.respond_to?(:attached?) && !target.attached?)

        target
      end
    end
  end
end
