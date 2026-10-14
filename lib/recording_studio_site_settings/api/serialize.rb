# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    module Serialize
      module_function

      def site_settings(root)
        { name: Store.name_for(root) }.merge(marks(root))
      end

      def marks(root)
        RecordingStudioSiteSettings::Admin::MARK_VARIANTS.to_h do |slot, variant|
          [slot.to_sym, mark(Store.public_send(:"#{slot}_for", root, variant: variant), variant)]
        end
      end

      def mark(logo, variant)
        {
          present: logo.present?,
          variant: variant.to_s,
          recording_id: logo.recording&.id,
          filename: logo.filename,
          preview_url: absolute_url(PreviewUrl.path_for(logo, variant))
        }
      end

      # API clients (ChatGPT, scripts) have no page or session, so preview URLs are absolute, signed, and expiring.
      # Base: configuration.public_url_options, else routes.default_url_options with a host, else the
      # current request. With none of those the path is returned unchanged.
      def absolute_url(path)
        return path if path.blank? || path.to_s.match?(%r{\A[a-z][a-z0-9+.-]*://}i)

        base = base_url
        base.present? ? "#{base.chomp('/')}#{path}" : path
      end

      def base_url
        options = configured_url_options
        return url_from_options(options) if options

        RecordingStudioSiteSettings::RequestBaseUrl.current.presence
      end

      def configured_url_options
        [RecordingStudioSiteSettings.configuration.public_url_options, routes_default_url_options].each do |options|
          options = options.to_h.symbolize_keys if options.respond_to?(:to_h)
          return options if options.is_a?(Hash) && options[:host].present?
        end
        nil
      end

      def routes_default_url_options
        Rails.application&.routes&.default_url_options if defined?(Rails) && Rails.respond_to?(:application)
      end

      def url_from_options(options)
        host = options[:host].to_s
        return host.chomp("/") if host.match?(%r{\Ahttps?://}i)

        protocol = options[:protocol].presence&.to_s&.delete_suffix("://") || "https"
        port = options[:port].presence
        default_port = { "http" => 80, "https" => 443 }[protocol]
        port_part = port && port.to_i != default_port ? ":#{port}" : ""
        "#{protocol}://#{host}#{port_part}"
      end
    end
  end
end
