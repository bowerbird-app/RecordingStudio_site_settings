# frozen_string_literal: true

module RecordingStudioSiteSettings
  class Configuration
    attr_accessor :site_root_types, :site_root_resolver
    attr_reader :hooks

    def initialize
      @site_root_types = ["Workspace"]
      @site_root_resolver = default_site_root_resolver
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      {
        site_root_types: site_root_types,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    private

    def default_site_root_resolver
      lambda do |context|
        controller = context.respond_to?(:controller) ? context.controller : context
        return unless controller.respond_to?(:current_root_recording)

        recording = controller.current_root_recording
        recording if RecordingStudioSiteSettings.site_root?(recording)
      end
    end
  end
end
