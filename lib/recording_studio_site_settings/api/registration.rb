# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    module Registration
      OPENAPI_TAGS = ["Site settings"].freeze

      module_function

      def register!
        register_show!
        register_update!
      end

      def register_show!
        register_site_settings_endpoint!(
          SHOW_ENDPOINT,
          http_verb: :get,
          handler: Show,
          openapi: openapi("Show site settings", show_description)
        )
      end

      def register_update!
        register_site_settings_endpoint!(
          UPDATE_ENDPOINT,
          http_verb: :patch,
          handler: Update,
          openapi: openapi("Update the site name", update_description),
          input_contract: update_input_contract
        )
      end

      def register_site_settings_endpoint!(name, http_verb:, handler:, openapi:, input_contract: nil)
        return unless registrable?(name)

        RecordingStudioApi.register_endpoint(
          name,
          api: OPERATIONS_API,
          http_verb: http_verb,
          path: SITE_SETTINGS_PATH,
          handler: handler,
          openapi: openapi,
          input_contract: input_contract
        )
      end

      def registrable?(name)
        return false unless operations_api_present?

        !already_registered?(name)
      end

      def openapi(summary, description)
        { tags: OPENAPI_TAGS, summary: summary, description: description }
      end

      def already_registered?(name)
        return false unless RecordingStudioApi.respond_to?(:registered_endpoint)

        RecordingStudioApi.registered_endpoint(name, api: OPERATIONS_API).present?
      end

      def operations_api_present?
        configuration = RecordingStudioApi.configuration if RecordingStudioApi.respond_to?(:configuration)
        return true unless configuration.respond_to?(:api_names)

        Array(configuration.api_names).map(&:to_s).include?(OPERATIONS_API.to_s)
      end

      def update_input_contract
        {
          reject_unknown: true,
          fields: {
            name: { type: :string, required: true }
          }
        }
      end

      def show_description
        "The site name and each mark (square logo, wide logo, favicon) for the site root. " \
          "Same access as the Site admin screen: Accessible :view on the site admin recording."
      end

      def update_description
        "Renames the site (name is stripped). Same access as saving the Site admin screen: " \
          "Accessible :admin on the site admin recording and :edit on the site root. " \
          "A blank name returns 422."
      end
    end
  end
end
