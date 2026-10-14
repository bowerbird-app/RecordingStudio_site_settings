# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    # ActiveRecord::RecordInvalid is left to the API controller, which renders it as 422.
    class Update
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        root = Access.write(context)
        RecordingStudioSiteSettings.update!(root, name: submitted_name, actor: Access.actor_for(context))
        Serialize.site_settings(root)
      rescue RecordingStudioSiteSettings::Unauthorized => e
        raise RecordingStudioApi::AuthorizationError, e.message
      end

      private

      attr_reader :context

      def submitted_name
        params = context&.params || {}
        (params[:name] || params["name"]).to_s.strip
      end
    end
  end
end
