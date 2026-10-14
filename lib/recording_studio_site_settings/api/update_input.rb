# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    # Reads the update body: an optional name and an optional logos object keyed by mark slot.
    # Each logo value is an https URL, a ChatGPT file object ({ download_url, file_id }), or null to clear.
    class UpdateInput
      FILE_OBJECT_KEYS = %i[download_url file_id mime_type file_name].freeze

      attr_reader :name, :sources, :clears

      def self.parse!(params)
        new(params).tap(&:validate!)
      end

      def initialize(params)
        params = (params || {}).to_h.deep_symbolize_keys
        @name_given = params.key?(:name)
        @name = params[:name].to_s.strip if @name_given
        @logos = params.key?(:logos) ? params[:logos] : {}
        @sources = {}
        @clears = []
        @errors = []
      end

      def name_given?
        @name_given
      end

      def validate!
        read_logos
        @errors << "Send name, logos, or both" if errors.empty? && !name_given? && sources.empty? && clears.empty?
        return if errors.empty?

        raise RecordingStudioApi::InvalidActionInputError.new("Invalid site settings update", details: errors)
      end

      private

      attr_reader :logos, :errors

      def read_logos
        return @errors << "logos must be an object keyed by #{slots.join(', ')}" unless logos.is_a?(Hash)

        logos.each { |slot, value| read_logo(slot.to_s, value) }
      end

      def read_logo(slot, value)
        return @errors << "logos.#{slot} is not a mark; use #{slots.join(', ')}" unless slots.include?(slot)
        return @clears << slot if value.nil?

        url = source_url(value)
        return @sources[slot] = url if url.present?

        @errors << "logos.#{slot} must be an https URL, a file object with download_url and file_id, or null"
      end

      def source_url(value)
        return value.strip if value.is_a?(String)
        return unless value.is_a?(Hash)

        file = value.symbolize_keys
        return unless (file.keys - FILE_OBJECT_KEYS).empty? && file[:file_id].is_a?(String) && file[:file_id].present?

        file[:download_url].strip if file[:download_url].is_a?(String)
      end

      def slots
        RecordingStudioSiteSettings::Admin::MARK_VARIANTS.keys
      end
    end
  end
end
