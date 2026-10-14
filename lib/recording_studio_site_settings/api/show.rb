# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    class Show
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Serialize.site_settings(Access.read(context))
      end

      private

      attr_reader :context
    end
  end
end
