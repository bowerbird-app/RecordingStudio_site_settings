# frozen_string_literal: true

require "ipaddr"

module RecordingStudioSiteSettings
  class Configuration
    REMOTE_IMAGE_ALLOWED_NETWORKS_ENV = "RECORDING_STUDIO_SITE_SETTINGS_REMOTE_IMAGE_ALLOWED_NETWORKS"

    attr_accessor :site_root_resolver
    attr_reader :site_root_types, :hooks, :remote_image_allowed_networks
    # Host/protocol/port for absolute preview URLs in API payloads, e.g. { host: "example.com", protocol: "https" }.
    # When nil, Rails.application.routes.default_url_options is used, then the current request's base URL.
    attr_accessor :public_url_options
    # Lifetime of the signed preview_url returned by the API.
    attr_accessor :preview_url_expires_in

    def initialize
      @site_root_types = ["Workspace"]
      @site_root_resolver = default_site_root_resolver
      @hooks = RecordingStudio::Hooks.new
      @public_url_options = nil
      @preview_url_expires_in = 10 * 60
      self.remote_image_allowed_networks = ENV.fetch(REMOTE_IMAGE_ALLOWED_NETWORKS_ENV, "")
    end

    # CIDRs a logo download may reach even though they are private or reserved, for hosts whose egress
    # proxy answers DNS with its own address (for example 198.18.0.0/15 fake-IP sandboxes). Loopback,
    # link-local (cloud metadata), and unspecified addresses stay refused. Empty by default.
    def remote_image_allowed_networks=(networks)
      list = networks.is_a?(String) ? networks.split(/[\s,]+/) : Array(networks)
      cidrs = list.map { |cidr| cidr.to_s.strip }.reject(&:empty?)
      @remote_image_allowed_networks = cidrs.map { |cidr| IPAddr.new(cidr) }.freeze
    end

    def to_h
      {
        site_root_types: site_root_types,
        remote_image_allowed_networks: remote_image_allowed_networks.map { |ip| "#{ip}/#{ip.prefix}" },
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def site_root_types=(types)
      @site_root_types = Array(types)
      RecordingStudioSiteSettings.sync_site_setting_parent_types!
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    def load_from_rails_app!(app)
      merge_x_config(app)
    end

    private

    def merge_x_config(app)
      xcfg = x_config_for(app)
      return if xcfg.blank?

      merge!(xcfg)
    rescue StandardError
      nil
    end

    def x_config_for(app)
      return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_site_settings)

      xcfg = app.config.x.recording_studio_site_settings
      return xcfg.to_h if xcfg.respond_to?(:to_h)
      return unless xcfg.respond_to?(:each_pair)

      xcfg.each_pair.with_object({}) { |(key, value), hash| hash[key] = value }
    end

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
