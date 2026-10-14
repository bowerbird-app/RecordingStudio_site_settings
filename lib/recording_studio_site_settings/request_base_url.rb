# frozen_string_literal: true

module RecordingStudioSiteSettings
  # Remembers the current request's base URL (scheme, host, port; proxy headers honored, after the host app's
  # host authorization) so API payloads can return absolute preview URLs. Cleared after every request.
  class RequestBaseUrl
    KEY = :recording_studio_site_settings_request_base_url

    class << self
      def current
        Thread.current[KEY]
      end

      def with(base_url)
        previous = Thread.current[KEY]
        Thread.current[KEY] = base_url
        yield
      ensure
        Thread.current[KEY] = previous
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      base_url = begin
        ActionDispatch::Request.new(env).base_url
      rescue StandardError
        nil
      end
      self.class.with(base_url) { @app.call(env) }
    end
  end
end
