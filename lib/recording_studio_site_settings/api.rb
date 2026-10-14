# frozen_string_literal: true

require_relative "api/access"
require_relative "api/preview_url"
require_relative "api/serialize"
require_relative "api/show"
require_relative "api/remote_image"
require_relative "api/update_input"
require_relative "api/update"
require_relative "api/registration"

module RecordingStudioSiteSettings
  module Api
    OPERATIONS_API = :operations
    SHOW_ENDPOINT = :site_settings_show
    UPDATE_ENDPOINT = :site_settings_update
    SITE_SETTINGS_PATH = "site_settings"

    class << self
      def register!
        return unless recording_studio_api_available?

        Registration.register!
        true
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_endpoint)
      end
    end
  end
end
