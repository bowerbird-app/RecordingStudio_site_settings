# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    # Reads the update body: an optional name and one optional top-level field per mark, named
    # "<slot>_file" for each Admin::MARK_VARIANTS slot. Each mark value is a file object
    # ({ download_url, file_id }, the shape ChatGPT sends), an https URL string, or null to clear.
    class UpdateInput
      FILE_SUFFIX = "_file"
      FILE_OBJECT_KEYS = %i[download_url file_id mime_type file_name].freeze

      attr_reader :name, :sources, :clears

      def self.parse!(params)
        new(params).tap(&:validate!)
      end

      def self.file_field(slot)
        :"#{slot}#{FILE_SUFFIX}"
      end

      def self.file_fields
        RecordingStudioSiteSettings::Admin::MARK_VARIANTS.keys.to_h { |slot| [file_field(slot), slot] }
      end

      def initialize(params)
        @params = (params || {}).to_h.deep_symbolize_keys
        @name_given = @params.key?(:name)
        @name = @params[:name].to_s.strip if @name_given
        @sources = {}
        @clears = []
        @errors = []
      end

      def name_given?
        @name_given
      end

      def validate!
        read_marks
        @errors << "Send name, at least one of #{file_fields.keys.join(', ')}, or both" if nothing_sent?
        return if errors.empty?

        raise RecordingStudioApi::InvalidActionInputError.new("Invalid site settings update", details: errors)
      end

      private

      attr_reader :params, :errors

      def file_fields
        self.class.file_fields
      end

      def nothing_sent?
        errors.empty? && !name_given? && sources.empty? && clears.empty?
      end

      def read_marks
        unknown = params.keys - [:name] - file_fields.keys
        @errors << "Unknown parameters: #{unknown.sort.join(', ')}" if unknown.any?
        file_fields.each { |field, slot| read_mark(field, slot) if params.key?(field) }
      end

      def read_mark(field, slot)
        value = params[field]
        return @clears << slot if value.nil?

        url = source_url(value)
        return @sources[slot] = url if url.present?

        @errors << "#{field} must be a file object with download_url and file_id, an https URL, or null"
      end

      def source_url(value)
        return value.strip if value.is_a?(String)
        return unless value.is_a?(Hash)

        file = value.symbolize_keys
        return unless (file.keys - FILE_OBJECT_KEYS).empty? && file[:file_id].is_a?(String) && file[:file_id].present?

        file[:download_url].strip if file[:download_url].is_a?(String)
      end
    end
  end
end
